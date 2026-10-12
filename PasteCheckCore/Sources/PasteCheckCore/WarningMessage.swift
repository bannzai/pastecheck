/// Builds the text of the warning notification shown for one clipboard change.
///
/// The text names only the kind, the position (line, column, character count) and the app that was frontmost,
/// never any part of the matched value, not even a masked prefix (`documents/PROJECT.md` invariant 1).
public enum WarningMessage {
    /// The notification title, e.g. "Looks like a GitHub token". When several kinds were found, the first one by
    /// position is named and the rest are counted.
    /// - Precondition: `findings` is not empty and sorted by position, as `SecretDetector.findings(in:)` returns.
    public static func title(findings: [Finding]) -> String {
        guard let first = findings.first else {
            return "Looks like a secret"
        }
        let otherKindCount = Set(findings.map(\.kind)).subtracting([first.kind]).count
        switch otherKindCount {
        case 0:
            return "Looks like \(first.kind.displayName)"
        case 1:
            return "Looks like \(first.kind.displayName) and 1 more kind of secret"
        default:
            return "Looks like \(first.kind.displayName) and \(otherKindCount) more kinds of secrets"
        }
    }

    /// The notification body: where the first finding is, how many other matches there are, and which app was
    /// frontmost. `frontmostAppName` is the app in front when the change was noticed, which is not necessarily the
    /// app the text was copied from, so the wording says "in front" and the part is left out when it is `nil`.
    public static func body(findings: [Finding], frontmostAppName: String?) -> String {
        guard let first = findings.first else {
            return "PasteCheck did not change the clipboard."
        }
        let otherMatchCount = findings.count - 1
        let location = "Line \(first.line), column \(first.column), \(first.length) characters"
        let others: String
        switch otherMatchCount {
        case 0:
            others = ""
        case 1:
            others = " (and 1 more match)"
        default:
            others = " (and \(otherMatchCount) more matches)"
        }
        let app = frontmostAppName.map { ", while \($0) was in front" } ?? ""
        return "\(location)\(others)\(app). PasteCheck did not change the clipboard."
    }
}
