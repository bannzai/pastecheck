import Foundation

/// Detects text that looks like a secret in clipboard text.
///
/// Every rule runs on-device and only reports where a match is, never the matched text
/// (`.claude/rules/clipboard-content-handling.md`).
///
/// Exclusions that keep false positives down, and why:
/// - Token prefixes (`AKIA`, `ghp_`, `sk-`, `xoxb-`, ...) must not be glued to a preceding or following
///   identifier character, so a prefix in the middle of a longer word does not count.
/// - OpenAI: the part after `sk-` must contain both a letter and a digit. Real keys are random base62,
///   while kebab-case words such as `sk-learn-...` are letters only.
/// - JWT: the first segment must base64url-decode to a JSON object with an `alg` member, as every JWS / JWE
///   header has (RFC 7515 section 4.1.1, RFC 7516 section 4.1.1). Any `eyJ...` text that is not a token header
///   is skipped. A dot right after the third segment ends the token (a sentence period), but a dot followed by
///   another segment means a longer dotted string such as a five-segment JWE, which this rule does not report.
/// - Credit card numbers: the digits must pass the Luhn check (ISO/IEC 7812-1) and start with 2–6. Card brands
///   issue from those leading digits (Mastercard 2/5, Amex and JCB and Diners 3, Visa 4, Discover and UnionPay 6),
///   while millisecond timestamps (`17...`) and most order or phone numbers start elsewhere.
/// - `.env` style `KEY=value`: the key must be upper snake case of 3+ characters, and the value must be 20+
///   characters with no whitespace that contains both a letter and a digit. Random tokens (hex, base62, base64)
///   always mix letters and digits, while paths like `PATH=/usr/bin:/bin` and plain words do not. A symbol is
///   not required because hex and base62 tokens have none. A trailing ` # comment` after the value is allowed, as
///   `.env` files commonly annotate values that way.
public enum SecretDetector {
    /// Returns every match of every rule in `text`, sorted by position (ties are broken by `SecretKind` order).
    /// Overlapping matches of different kinds are all reported; the caller decides how to summarize them.
    public static func findings(in text: String) -> [Finding] {
        SecretKind.allCases
            .flatMap { kind in
                ranges(kind: kind, text: text).map { range in
                    Finding(kind: kind, range: range, text: text)
                }
            }
            .sorted { lhs, rhs in
                if lhs.range.lowerBound != rhs.range.lowerBound {
                    return lhs.range.lowerBound < rhs.range.lowerBound
                }
                return lhs.kind.sortOrder < rhs.kind.sortOrder
            }
    }

    /// The ranges in `text` that `kind`'s rule matches. Boundaries are matched by a non-capturing prefix group
    /// plus a negative lookahead, and the reported range is the capture, so the boundary character is excluded.
    static func ranges(kind: SecretKind, text: String) -> [Range<String.Index>] {
        switch kind {
        case .awsAccessKeyID:
            return text.matches(of: /(?:^|[^A-Za-z0-9])(AKIA[A-Z0-9]{16})(?![A-Za-z0-9])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .githubToken:
            return text.matches(of: /(?:^|[^A-Za-z0-9_])((?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}))(?![A-Za-z0-9_])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .openAIKey:
            return text.matches(of: /(?:^|[^A-Za-z0-9_-])(sk-([A-Za-z0-9_-]{20,}))(?![A-Za-z0-9_-])/)
                .filter { containsLetterAndDigit(value: $0.output.2) }
                .map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .slackToken:
            return text.matches(of: /(?:^|[^A-Za-z0-9])(xox[abprs]-[A-Za-z0-9-]{10,})(?![A-Za-z0-9-])/).map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .jwt:
            return text.matches(of: /(?:^|[^A-Za-z0-9_-])((eyJ[A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)(?![A-Za-z0-9_-]|\.[A-Za-z0-9_-])/)
                .filter { isJOSEHeader(base64URLSegment: $0.output.2) }
                .map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .pemPrivateKey:
            // The END line is optional so a copied header alone still warns; when present, the range covers the block.
            return text.matches(of: /-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----(?:[\s\S]*?-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----)?/).map { $0.range }
        case .creditCardNumber:
            return text.matches(of: /(?:^|[^0-9])([2-6][0-9](?:[ -]?[0-9]){11,17})(?![0-9])/)
                .filter { passesLuhn(digits: String($0.output.1.filter(\.isNumber))) }
                .map { $0.output.1.startIndex..<$0.output.1.endIndex }
        case .envAssignment:
            return text.matches(of: /^[ \t]*(?:#[ \t]*)?(?:export[ \t]+)?[A-Z][A-Z0-9_]{2,}=(["']?)([^\s"'#]{20,})\1(?:[ \t]+#[^\r\n]*)?[ \t]*$/.anchorsMatchLineEndings())
                .filter { containsLetterAndDigit(value: $0.output.2) }
                .map { $0.output.2.startIndex..<$0.output.2.endIndex }
        }
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

    /// Derives `line`, `column` and `length` from `range` in `text`, so callers cannot pass inconsistent positions.
    init(kind: SecretKind, range: Range<String.Index>, text: String) {
        let prefix = text[..<range.lowerBound]
        let lineStart = prefix.lastIndex(where: \.isNewline).map { text.index(after: $0) } ?? text.startIndex
        self.init(
            kind: kind,
            range: range,
            line: prefix.filter(\.isNewline).count + 1,
            column: text.distance(from: lineStart, to: range.lowerBound) + 1,
            length: text.distance(from: range.lowerBound, to: range.upperBound)
        )
    }

    public var description: String {
        "\(kind.rawValue) at line \(line), column \(column), \(length) characters"
    }

    public var debugDescription: String {
        "Finding(\(description))"
    }
}
