/// Turns the text that OCR recognized in a copied image into the string `SecretDetector` inspects.
///
/// The recognized text exists only in memory while it is inspected and is never stored, logged, or shown
/// (`.claude/rules/clipboard-content-handling.md`).
public enum RecognizedText {
    /// Joins the recognized lines, one per text region OCR found, into one string for `SecretDetector.findings(in:)`.
    /// A line break separates the regions so a token in one region is never glued to the text of the next one, and so
    /// line-anchored rules (`.env` style `KEY=value`, PEM headers) see each region as its own line.
    public static func inspectableText(lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
