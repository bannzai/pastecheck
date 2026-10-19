/// Builds the text of the warning notification shown for one clipboard change.
///
/// The text names only the kind, the position (line, column, character count, or "in the copied image") and the app
/// that was frontmost, never any part of the matched value, not even a masked prefix (`documents/PROJECT.md`
/// invariant 1).
public enum WarningMessage {
    /// The notification title, e.g. "Looks like a GitHub token". When several kinds were found, the first one is
    /// named and the rest are counted.
    /// - Precondition: `findings` is not empty and in the order to name them: the text findings sorted by position, as
    ///   `SecretDetector.findings(in:)` returns, followed by the image findings.
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
    /// frontmost. One clipboard change can carry both text and an image, and the app that receives the paste picks
    /// which one it reads, so both are inspected and reported in this one body instead of two warnings.
    ///
    /// `frontmostAppName` is the app in front when the change was noticed, which is not necessarily the app the
    /// content was copied from, so the wording says "in front" and the part is left out when it is `nil`.
    /// For an image, the position is only "in the copied image": lines and columns of OCR output do not map to
    /// anything the user can find in the picture.
    public static func body(textFindings: [Finding], imageFindings: [Finding], frontmostAppName: String?) -> String {
        let location: String
        if let first = textFindings.first {
            let alsoInImage = imageFindings.isEmpty ? "" : ", also in the copied image"
            location = "Line \(first.line), column \(first.column), \(first.length) characters\(alsoInImage)"
        } else if !imageFindings.isEmpty {
            location = "In the copied image"
        } else {
            return "PasteCheck did not change the clipboard."
        }
        let others: String
        switch textFindings.count + imageFindings.count - 1 {
        case 0:
            others = ""
        case 1:
            others = " (and 1 more match)"
        case let otherMatchCount:
            others = " (and \(otherMatchCount) more matches)"
        }
        let app = frontmostAppName.map { ", while \($0) was in front" } ?? ""
        return "\(location)\(others)\(app). PasteCheck did not change the clipboard."
    }

    /// The notification title when the copied text holds the value of a secret saved in SecChain
    /// (`documents/design/mock-2026-10-11/WarningSecChain.dc.html`).
    /// - Precondition: `matchedLabels` is not empty.
    public static func secChainTitle(matchedLabels: [String]) -> String {
        guard matchedLabels.count > 1 else {
            return "Your clipboard holds a secret saved in SecChain"
        }
        return "Your clipboard holds \(matchedLabels.count) secrets saved in SecChain"
    }

    /// The notification body for a SecChain match: the first matched secret by the label `secchain match` gave it (its
    /// name and where it is stored, never its value), how many others matched, how many look-alikes were found in the
    /// copied image, and which app was frontmost. The image findings are counted because the image text is not matched
    /// against SecChain, so they cannot be the same value as a SecChain match; the copied text's own pattern findings
    /// are left out, as they most likely are (`documents/DIRECTION.md` "決めたこと", 2026-10-19).
    /// - Precondition: `matchedLabels` is not empty, in the order `secchain match` wrote them.
    public static func secChainBody(matchedLabels: [String], imageFindings: [Finding], frontmostAppName: String?) -> String {
        guard let first = matchedLabels.first else {
            return "PasteCheck did not change the clipboard."
        }
        let others: String
        switch matchedLabels.count - 1 {
        case 0:
            others = ""
        case 1:
            others = " and 1 more saved secret"
        case let otherCount:
            others = " and \(otherCount) more saved secrets"
        }
        let app = frontmostAppName.map { ", while \($0) was in front" } ?? ""
        let image: String
        switch imageFindings.count {
        case 0:
            image = ""
        case 1:
            image = " The copied image also holds 1 look-alike."
        case let imageFindingCount:
            image = " The copied image also holds \(imageFindingCount) look-alikes."
        }
        return "Contains the value of \(first)\(others)\(app). This is your real secret, not a look-alike.\(image) PasteCheck did not change the clipboard."
    }
}
