import Foundation
import Vision

/// Recognizes the text in a copied image with Vision, on the device and without any permission
/// (`documents/PROJECT.md` invariant 1).
///
/// The recognized text is returned to the caller only to be inspected, and is never stored, logged, or shown
/// (`.claude/rules/clipboard-content-handling.md`).
///
/// OCR has no on/off setting and always runs (`documents/DIRECTION.md` "決めたこと", 2026-10-13).
enum ImageTextRecognizer {
    /// The text lines Vision recognized in `imageData` (PNG or TIFF), one per text region, or an empty array when the
    /// image has no text or cannot be read or the calling task is cancelled. Recognition is slow on a large image, so
    /// it runs off the main actor, and cancelling the calling task cancels the Vision request so a replaced image does
    /// not keep using the CPU.
    nonisolated static func recognizedLines(imageData: Data) async -> [String] {
        let request = CancellableRequest(request: textRecognitionRequest())
        return await withTaskCancellationHandler {
            // `.userInitiated`, because the user just copied and is about to paste, so the warning must not wait
            // behind background work.
            await Task.detached(priority: .userInitiated) {
                do {
                    try VNImageRequestHandler(data: imageData).perform([request.request])
                } catch {
                    return []
                }
                return (request.request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            }.value
        } onCancel: {
            request.request.cancel()
        }
    }

    /// The request configured for reading secrets.
    nonisolated private static func textRecognitionRequest() -> VNRecognizeTextRequest {
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
        return request
    }
}

/// A Vision request shared between the task that performs it and the cancellation handler that cancels it.
/// `@unchecked Sendable` because `VNRequest` is not marked `Sendable`; the cancellation handler only calls `cancel()`,
/// which "cancels the request before it can finish executing"
/// (https://developer.apple.com/documentation/vision/vnrequest/cancel() ), so it is called while `perform` runs.
private struct CancellableRequest: @unchecked Sendable {
    /// The request being performed.
    let request: VNRecognizeTextRequest
}
