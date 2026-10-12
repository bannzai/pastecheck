import Foundation
import Vision

/// Recognizes the text in a copied image with Vision, on the device and without any permission
/// (`documents/PROJECT.md` invariant 1).
///
/// The recognized text is returned to the caller only to be inspected, and is never stored, logged, or shown
/// (`.claude/rules/clipboard-content-handling.md`).
enum ImageTextRecognizer {
    /// The `UserDefaults` key of the "Text inside images (OCR)" detection switch. The menu row that changes it comes
    /// with the menu bar settings (https://github.com/bannzai/pastecheck/issues/10); until then only this key exists.
    static let isEnabledKey = "detectsTextInImages"

    /// Whether copied images are inspected. When the key is unset it is `true`, because OCR inspection is one of the
    /// MVP features (`documents/DIRECTION.md` "必要な機能") and the switch is for turning it off.
    static func isEnabled(defaults: UserDefaults) -> Bool {
        defaults.object(forKey: isEnabledKey) as? Bool ?? true
    }

    /// The text lines Vision recognized in `imageData` (PNG or TIFF), one per text region, or an empty array when the
    /// image has no text or cannot be read. Synchronous and slow on a large image, so call it off the main actor.
    nonisolated static func recognizedLines(imageData: Data) -> [String] {
        let request = VNRecognizeTextRequest()
        // The rules need every character of a token right, and `.fast` "returns results faster at the expense of
        // accuracy" (https://developer.apple.com/documentation/vision/vnrequesttextrecognitionlevel/fast ). The cost is
        // time, which is spent off the main actor.
        request.recognitionLevel = .accurate
        // English first, because the secrets the rules look for are ASCII. Japanese is added for the maker's own
        // screenshots of Japanese UIs (the `KEY=value` label or setting name next to a key), which `.accurate` reads
        // only when the language is listed. Japanese came with `VNRecognizeTextRequestRevision3` (WWDC22 "What's new in
        // Vision": https://developer.apple.com/videos/play/wwdc2022/10024/ ), which the macOS 15 deployment target has.
        request.recognitionLanguages = ["en-US", "ja-JP"]
        // Language correction rewrites random strings toward dictionary words, which corrupts exactly the tokens the
        // rules look for.
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(data: imageData).perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
