import Foundation

/// Detects text that looks like a secret in clipboard text.
///
/// Every rule runs on-device and only reports where a match is, never the matched text
/// (`.claude/rules/clipboard-content-handling.md`).
///
/// Exclusions that keep false positives down, and why:
/// - Token prefixes (`AKIA`, `ASIA`, `ghp_`, `sk-`, `xoxb-`, ...) must not be glued to a preceding or following
///   identifier character, so a prefix in the middle of a longer word does not count.
/// - OpenAI: the part after `sk-` must contain both a letter and a digit. Real keys are random base62,
///   while kebab-case words such as `sk-learn-...` are letters only.
/// - JWT: the first segment must base64url-decode to a JSON object with an `alg` member, as every JWS / JWE
///   header has (RFC 7515 section 4.1.1, RFC 7516 section 4.1.1). Any `eyJ...`-like text that is not a token header
///   is skipped. A dot right after the third segment ends the token (a sentence period), but a dot followed by
///   another segment means a longer dotted string such as a five-segment JWE, which this rule does not report.
/// - Credit card numbers: the digits must pass the Luhn check (ISO/IEC 7812-1) and start with 2–6. Card brands
///   issue from those leading digits (Mastercard 2/5, Amex and JCB and Diners 3, Visa 4, Discover and UnionPay 6),
///   while millisecond timestamps (`17...`) and most order or phone numbers start elsewhere.
/// - `.env` style `KEY=value`: the key must be upper snake case of 3+ characters, and the value must be 20+
///   characters with no whitespace that contains both a letter and a digit. Random tokens (hex, base62, base64)
///   always mix letters and digits, while paths like `PATH=/usr/bin:/bin` and plain words do not. A symbol is
///   not required because hex and base62 tokens have none. A trailing ` # comment` after the value is allowed, as
///   `.env` files commonly annotate values that way. A URL value is skipped unless it carries credentials (`@`).
public enum SecretDetector {
    /// Returns every match of the rules of `kinds` in `text`, sorted by position (ties are broken by `SecretKind` order).
    /// Overlapping matches of different kinds are all reported; the caller decides how to summarize them.
    /// - Parameter kinds: The kinds to look for. Every kind when omitted, because a kind is skipped only when the user
    ///   turned its "Detect" checkbox off in the menu, and the app passes that setting explicitly.
    public static func findings(in text: String, kinds: Set<SecretKind> = Set(SecretKind.allCases)) -> [Finding] {
        let matches = SecretKind.allCases
            .filter { kinds.contains($0) }
            .flatMap { kind in
                ranges(kind: kind, text: text).map { range in
                    (kind: kind, range: range)
                }
            }
            .sorted { lhs, rhs in
                if lhs.range.lowerBound != rhs.range.lowerBound {
                    return lhs.range.lowerBound < rhs.range.lowerBound
                }
                return lhs.kind.sortOrder < rhs.kind.sortOrder
            }
        // Line and column are accumulated in one forward pass over the sorted matches, so the text before the matches
        // is scanned once in total. Rescanning from the start, or from the line start, for each match is quadratic on
        // a copied log or single-line JSON with many matches, and this runs on the main actor.
        var cursor = text.startIndex
        var line = 1
        var column = 1
        return matches.map { match in
            while cursor < match.range.lowerBound {
                if text[cursor].isNewline {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
                cursor = text.index(after: cursor)
            }
            return Finding(
                kind: match.kind,
                range: match.range,
                line: line,
                column: column,
                length: text.distance(from: match.range.lowerBound, to: match.range.upperBound)
            )
        }
    }

    /// The ranges in `text` that `kind`'s rule matches. Boundaries are matched by a non-capturing prefix group
    /// plus a negative lookahead, and the reported range is the capture, so the boundary character is excluded.
    static func ranges(kind: SecretKind, text: String) -> [Range<String.Index>] {
        switch kind {
        case .awsAccessKeyID:
            // `AKIA` is an access key and `ASIA` a temporary (AWS STS) access key ID, per the AWS IAM User Guide
            // "Understanding unique ID prefixes": https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html
            return text.matches(of: /(?:^|[^A-Za-z0-9])(A[KS]IA[A-Z0-9]{16})(?![A-Za-z0-9])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .githubToken:
            return text.matches(of: /(?:^|[^A-Za-z0-9_])((?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}))(?![A-Za-z0-9_])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .openAIKey:
            return text.matches(of: /(?:^|[^A-Za-z0-9_-])(sk-([A-Za-z0-9_-]{20,}))(?![A-Za-z0-9_-])/)
                .filter { containsLetterAndDigit(value: $0.output.2) }
                .map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .slackToken:
            return text.matches(of: /(?:^|[^A-Za-z0-9])(xox[abprs]-[A-Za-z0-9-]{10,})(?![A-Za-z0-9-])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .jwt:
            // A JSON object starts with `{` (0x7B), whose base64 is `e` followed by one of `w`–`z` depending on the next
            // byte (`eyJ` for `{"`, `eyA` for `{ `, `ewo` for a newline), so the candidate is not limited to `eyJ`.
            return text.matches(of: /(?:^|[^A-Za-z0-9_-])((e[w-z][A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)(?![A-Za-z0-9_-]|\.[A-Za-z0-9_-])/)
                .filter { isJOSEHeader(base64URLSegment: $0.output.2) }
                .map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .pemPrivateKey:
            // The END line is optional so a copied header alone still warns; when present, the range covers the block.
            // The END line is searched for only up to the next BEGIN line, so text with many headers and no END lines
            // is scanned once instead of once per header to the end.
            let headers = text.matches(of: /-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/).map(\.range)
            return headers.enumerated().map { offset, header in
                let searchEnd = offset + 1 < headers.count ? headers[offset + 1].lowerBound : text.endIndex
                guard let end = text[header.upperBound..<searchEnd].firstMatch(of: /-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----/) else {
                    return header
                }
                return header.lowerBound..<end.range.upperBound
            }
        case .creditCardNumber:
            return text.matches(of: /(?:^|[^0-9])([0-9](?:[ -]?[0-9]){12,})(?![0-9])/)
                .flatMap { cardNumberRanges(digitRun: $0.output.1) }
        case .envAssignment:
            // Inside quotes `#` is part of the value; unquoted, it starts a comment.
            return text.matches(of: /^[ \t]*(?:#[ \t]*)?(?:export[ \t]+)?[A-Z][A-Z0-9_]{2,}=(?:"([^\s"]{20,})"|'([^\s']{20,})'|([^\s"'#]{20,}))(?:[ \t]+#[^\r\n]*)?[ \t]*$/.anchorsMatchLineEndings())
                .compactMap { $0.output.1 ?? $0.output.2 ?? $0.output.3 }
                .filter { containsLetterAndDigit(value: $0) && !isURLWithoutCredentials(value: $0) }
                .map { $0.startIndex..<$0.endIndex }
        }
    }

    /// Whether `value` is a URL (`scheme://...`) with no `@`. Endpoint settings such as
    /// `API_URL=https://api.example.com/v2` are not secrets, while a URL with `user:password@` in it is one.
    static func isURLWithoutCredentials(value: Substring) -> Bool {
        value.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.-]*:\/\//) != nil && !value.contains("@")
    }

    /// Whether `value` has at least one letter and one digit, the shape of a random token rather than a word or path.
    static func containsLetterAndDigit(value: Substring) -> Bool {
        value.contains(where: \.isLetter) && value.contains(where: \.isNumber)
    }

    /// Whether `base64URLSegment` decodes to a JSON object that has an `alg` member (a JWS / JWE header).
    static func isJOSEHeader(base64URLSegment: Substring) -> Bool {
        let base64 = base64URLSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let header = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return header["alg"] is String
    }

    /// The card numbers in `digitRun`, a run of digits joined by single spaces or hyphens. A number may start at the run's
    /// start or right after a separator, so a count or ID written before it (`23 4242 4242 4242 4242`) does not hide it.
    /// After a number is found, the search continues after its end.
    static func cardNumberRanges(digitRun: Substring) -> [Range<String.Index>] {
        var cardRanges: [Range<String.Index>] = []
        var start = digitRun.startIndex
        while start < digitRun.endIndex {
            if let cardRange = cardNumberRange(candidate: digitRun[start...]) {
                cardRanges.append(cardRange)
                start = cardRange.upperBound
            } else {
                start = digitRun.index(after: start)
            }
            // Move to the next group start: skip the rest of the current group, then the separator.
            while start < digitRun.endIndex, start > digitRun.startIndex, digitRun[digitRun.index(before: start)].isNumber {
                start = digitRun.index(after: start)
            }
            while start < digitRun.endIndex, !digitRun[start].isNumber {
                start = digitRun.index(after: start)
            }
        }
        return cardRanges
    }

    /// The shortest leading part of `candidate` that is a card number: 13–19 digits starting with 2–6 that pass the Luhn
    /// check and end at a separator or at the end of `candidate`. A following field separated by a space, such as the
    /// expiry month in `4242 4242 4242 4242 12/30`, is therefore not glued onto the number. The shortest is taken
    /// because a longer run passes Luhn by chance one time in ten, and grouped card numbers end at their first group
    /// boundary of 13 or more digits (4-4-4-4 at 16, Amex 4-6-5 at 15).
    /// - Returns: `nil` when no such part exists.
    static func cardNumberRange(candidate: Substring) -> Range<String.Index>? {
        guard let first = candidate.first, ("2"..."6").contains(first) else {
            return nil
        }
        var digitCount = 0
        for index in candidate.indices where candidate[index].isNumber {
            digitCount += 1
            guard digitCount <= 19 else {
                break
            }
            let end = candidate.index(after: index)
            guard digitCount >= 13, end == candidate.endIndex || !candidate[end].isNumber else {
                continue
            }
            if passesLuhn(digits: String(candidate[..<end].filter(\.isNumber))) {
                return candidate.startIndex..<end
            }
        }
        return nil
    }

    /// The Luhn (mod 10) check used by payment card numbers (ISO/IEC 7812-1).
    static func passesLuhn(digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard (13...19).contains(values.count) else {
            return false
        }
        let sum = values.reversed().enumerated().reduce(0) { sum, element in
            guard element.offset % 2 == 1 else {
                return sum + element.element
            }
            let doubled = element.element * 2
            return sum + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }
}

/// The kinds of secrets `SecretDetector` recognizes. Declaration order is the tiebreak when two findings start
/// at the same position.
public enum SecretKind: String, CaseIterable, Sendable {
    case awsAccessKeyID
    case githubToken
    case openAIKey
    case slackToken
    case jwt
    case pemPrivateKey
    case creditCardNumber
    case envAssignment

    /// The name shown to the user in a warning, e.g. "Looks like a GitHub token".
    public var displayName: String {
        switch self {
        case .awsAccessKeyID:
            return "an AWS access key ID"
        case .githubToken:
            return "a GitHub token"
        case .openAIKey:
            return "an OpenAI API key"
        case .slackToken:
            return "a Slack token"
        case .jwt:
            return "a JSON Web Token"
        case .pemPrivateKey:
            return "a private key"
        case .creditCardNumber:
            return "a credit card number"
        case .envAssignment:
            return "a secret in a KEY=value line"
        }
    }

    /// The position of this kind in the declaration, used as the tiebreak in `SecretDetector.findings(in:)`.
    var sortOrder: Int {
        // Unreachable fallback: every case is in `allCases`. Sorting last keeps the order stable if it ever fires.
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

/// One detected secret. It holds only the kind and where the match is, never the matched text, so it is safe to
/// log, show, or print (`.claude/rules/clipboard-content-handling.md`).
public struct Finding: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// What the match looks like.
    public let kind: SecretKind
    /// The matched range in the inspected string. Only valid for that string.
    public let range: Range<String.Index>
    /// The 1-based line of the start of the match. `\n`, `\r\n` and other line breaks each count as one.
    public let line: Int
    /// The 1-based column, in characters, of the start of the match within its line.
    public let column: Int
    /// The number of characters in the match.
    public let length: Int

    public init(kind: SecretKind, range: Range<String.Index>, line: Int, column: Int, length: Int) {
        self.kind = kind
        self.range = range
        self.line = line
        self.column = column
        self.length = length
    }

    public var description: String {
        "\(kind.rawValue) at line \(line), column \(column), \(length) characters"
    }

    public var debugDescription: String {
        "Finding(\(description))"
    }
}
