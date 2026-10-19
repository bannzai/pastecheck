import AppKit
import Observation
import PasteCheckCore

/// Watches the general pasteboard, inspects new text and the text recognized in a new image with `SecretDetector`,
/// matches new text against SecChain when "SecChain secrets" is on, and warns once per change through
/// `WarningNotifier`. Holds the state shown at the top of the menu.
///
/// The clipboard text, image, and recognized text live only in locals of `inspectIfChanged()` and its inspection
/// task, and are never stored, logged or sent anywhere, except for the text handed to SecChain on this Mac by
/// `SecChainMatcher` (`documents/PROJECT.md` invariant 1).
@MainActor
@Observable
final class ClipboardMonitor {
    /// Whether PasteCheck may read the clipboard right now.
    enum AccessState {
        /// Reads are allowed and new clipboard text is inspected.
        case watching
        /// macOS would ask or deny on a read, so nothing is read until the user allows access in System Settings.
        case needsPermission
    }

    /// What the menu bar icon and the top of the menu show, the first matching case in declaration order.
    enum Status {
        /// The first-launch window was not closed yet, so nothing is inspected.
        case setupNotFinished
        /// The user paused inspection from the menu.
        case paused
        /// Inspection is on but macOS would ask or deny on a read (`AccessState.needsPermission`).
        case needsPermission
        /// New clipboard content is inspected.
        case watching
    }

    /// AppKit has no change notification for the pasteboard, so `changeCount` is polled. Half a second is short
    /// enough that a warning arrives before a typical copy-switch-paste, and comparing one integer that often costs
    /// next to nothing.
    static let pollingInterval: Duration = .milliseconds(500)
    /// The `UserDefaults` key of the flag set when the first-launch window is closed. Unset means the window has not
    /// been closed on this Mac yet.
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private(set) var accessState: AccessState
    /// When new clipboard text was last inspected; `nil` until the first change after launch.
    private(set) var lastCheckedAt: Date?
    /// The stored per-day warning counts, refreshed whenever a warning is recorded.
    private(set) var warningCountsByDay: [String: Int]
    /// Whether the first-launch window was closed once. Until then nothing is inspected, so the macOS clipboard access
    /// alert does not appear before that window explains it.
    private(set) var hasCompletedOnboarding: Bool
    /// The pause set from the menu. Kept in memory only, so relaunching the app always starts inspecting again.
    private(set) var pause: Pause = .notPaused
    /// Whether the last SecChain match got an answer: `true` when SecChain answered (the tool passed the signature
    /// checks and exited normally; whether it found the stored values is seen only from a match), `false` when it did not (`SecChainMatchOutcome.failed`, so the copy was checked
    /// against PasteCheck's own patterns only), and `nil` until a match has run with SecChain installed. The matched
    /// names are not kept.
    private(set) var lastSecChainMatchAnswered: Bool?

    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    /// The image recognition and SecChain match of the content copied last, while they run.
    @ObservationIgnored private var inspectionTask: Task<Void, Never>?

    /// The state shown in the menu bar icon and at the top of the menu.
    var status: Status {
        if !hasCompletedOnboarding {
            return .setupNotFinished
        }
        if pause.isActive(now: Date()) {
            return .paused
        }
        switch accessState {
        case .needsPermission:
            return .needsPermission
        case .watching:
            return .watching
        }
    }

    /// Starts polling at once. Whatever was already on the clipboard at launch is not read, so launching never
    /// triggers the macOS clipboard access alert by itself.
    init() {
        accessState = Self.currentAccessState()
        warningCountsByDay = WarningCountStore.warnings(defaults: .standard)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
        lastChangeCount = NSPasteboard.general.changeCount
        if hasCompletedOnboarding {
            WarningNotifier.requestAuthorization()
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollingInterval)
                self?.inspectIfChanged()
            }
        }
    }

    /// Starts inspecting and remembers that the first-launch window was closed, so it is not shown at the next launch.
    /// Also asks for notification permission, which the user may have skipped in the window: without it no warning can
    /// be shown. Idempotent: the flag is only set, and the system asks for permission once.
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        hasCompletedOnboarding = true
        WarningNotifier.requestAuthorization()
    }

    /// Sets the pause; `.notPaused` resumes. What was copied before this call is not inspected afterwards, and an image
    /// recognition or SecChain match still running is cancelled, because the user chose not to have that content checked.
    /// Idempotent for the same `pause`.
    func updatePause(pause: Pause) {
        self.pause = pause
        inspectionTask?.cancel()
        inspectionTask = nil
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Brings up the macOS clipboard access alert from the first-launch window by reading the clipboard once, or opens
    /// the setting in System Settings when macOS would no longer ask (the user already answered the alert).
    /// What is read is dropped at once: it is not inspected, stored, or shown (`documents/PROJECT.md` invariant 1).
    /// With an empty clipboard nothing is read, and the alert appears on the first copy after setup instead.
    func requestAccess() {
        if #available(macOS 15.4, *), NSPasteboard.general.accessBehavior != .default {
            ExternalLinks.openClipboardAccessSettings()
            return
        }
        if let type = NSPasteboard.general.types?.first {
            _ = NSPasteboard.general.data(forType: type)
        }
        updateAccessState()
    }

    /// Reads and inspects the clipboard once per `changeCount` change. Reading only on a change, and not at all while
    /// access would ask or deny, keeps macOS from showing its access alert again and again.
    private func inspectIfChanged() {
        // Refreshed on every poll, not only on a clipboard change, so allowing access in System Settings updates the
        // icon right away. While access is needed, `lastChangeCount` is left alone, so the content copied in the
        // meantime is inspected as soon as access is allowed.
        updateAccessState()
        let pasteboard = NSPasteboard.general
        // Written only when the timed pause ends, so the icon and menu switch back to watching on their own. This poll
        // inspects nothing, because a change since the last poll may have been copied while still paused (just before
        // the end, or before the Mac slept through it). A copy in the same half second after the end is skipped too.
        if case .until = pause, !pause.isActive(now: Date()) {
            updatePause(pause: .notPaused)
            return
        }
        // Content copied before setup or while paused is skipped for good: during setup reading it would bring up the
        // access alert too early, and while paused the user chose not to have it checked.
        guard hasCompletedOnboarding, !pause.isActive(now: Date()) else {
            lastChangeCount = pasteboard.changeCount
            return
        }
        guard accessState == .watching, pasteboard.changeCount != lastChangeCount else {
            return
        }
        let changeCount = pasteboard.changeCount
        let text = pasteboard.string(forType: .string)
        // The first read in the `.default` behavior shows the system alert, after which the behavior becomes `.ask`
        // or whatever the user picked, so it is read again for the menu and before reading an image.
        updateAccessState()
        // Text and an image are both read: the app that receives the paste picks which one it takes, so skipping
        // either could miss the one that gets pasted.
        let imageData = accessState == .watching ? Self.imageData(pasteboard: pasteboard) : nil
        // Another copy during the reads would pair new content with the old count, which double-counts the warning and
        // makes "Clear clipboard" a no-op, so that read is dropped and retried on the next poll.
        guard pasteboard.changeCount == changeCount else {
            return
        }
        // A read the user denied in that alert is left unprocessed, so the content is inspected once access is allowed.
        guard text != nil || accessState == .watching else {
            return
        }
        lastChangeCount = changeCount
        lastCheckedAt = Date()
        // The clipboard changed, so a recognition or match still running is about content that is no longer there.
        inspectionTask?.cancel()
        inspectionTask = nil
        let frontmostAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        let kinds = DetectionSettingsStore.enabledKinds(defaults: .standard)
        let textFindings = text.map { SecretDetector.findings(in: $0, kinds: kinds) } ?? []
        // Only the copied text goes to SecChain, not the text recognized in an image: `documents/PROJECT.md` "Features"
        // scopes the match to clipboard text, and OCR output can misread the characters of a value anyway.
        let secChainText = DetectionSettingsStore.matchesSecChainSecrets(defaults: .standard) ? text : nil
        // The warning waits for the image recognition and the SecChain match so that one copy gives one warning
        // covering everything. Polling goes on while both run off the main actor. `imageData` is `nil` also when the
        // clipboard holds no image to inspect, which is not a permission problem.
        inspectionTask = Task { [weak self] in
            async let lines = Self.recognizedLines(imageData: imageData)
            async let secChainOutcome = Self.secChainOutcome(text: secChainText)
            let imageFindings = SecretDetector.findings(in: RecognizedText.inspectableText(lines: await lines), kinds: kinds)
            let outcome = await secChainOutcome
            // A copy made meanwhile replaced the content, so this result is dropped. A cancelled match stopped the tool
            // on purpose, so it does not count as a failure either.
            guard !Task.isCancelled, NSPasteboard.general.changeCount == changeCount else {
                return
            }
            switch outcome {
            case .matched:
                self?.updateLastSecChainMatchAnswered(lastSecChainMatchAnswered: true)
            case .failed:
                self?.updateLastSecChainMatchAnswered(lastSecChainMatchAnswered: false)
            case .notInstalled:
                // A SecChain installed again later is a different tool, which has not answered yet.
                self?.forgetSecChainMatch()
            case nil:
                break
            }
            self?.warnIfFound(
                textFindings: textFindings,
                imageFindings: imageFindings,
                secChainLabels: outcome?.matchedLabels ?? [],
                frontmostAppName: frontmostAppName,
                changeCount: changeCount
            )
        }
    }

    /// The text lines recognized in `imageData`, or none without an image.
    nonisolated private static func recognizedLines(imageData: Data?) async -> [String] {
        guard let imageData else {
            return []
        }
        return await ImageTextRecognizer.recognizedLines(imageData: imageData)
    }

    /// The SecChain match of `text`, or `nil` when there is nothing to match (no text, or "SecChain secrets" is off).
    nonisolated private static func secChainOutcome(text: String?) async -> SecChainMatchOutcome? {
        guard let text else {
            return nil
        }
        return await SecChainMatcher.match(text: text)
    }

    /// Clears `lastSecChainMatchAnswered`, so the menu does not show the answer of an earlier link, for example after
    /// "SecChain secrets" was turned off and on again. Idempotent.
    func forgetSecChainMatch() {
        guard lastSecChainMatchAnswered != nil else {
            return
        }
        lastSecChainMatchAnswered = nil
    }

    /// Sets `lastSecChainMatchAnswered` only when it changed, for the same re-render reason as `updateAccessState()`.
    private func updateLastSecChainMatchAnswered(lastSecChainMatchAnswered: Bool) {
        guard self.lastSecChainMatchAnswered != lastSecChainMatchAnswered else {
            return
        }
        self.lastSecChainMatchAnswered = lastSecChainMatchAnswered
    }

    /// The image on `pasteboard` to recognize text in, or `nil` when there is no image.
    /// A copied file is out of scope (https://github.com/bannzai/pastecheck/issues/9 ), so a pasteboard with a file
    /// URL is not read as an image, whatever image type it also offers. Both PNG and TIFF are formats Vision reads.
    private static func imageData(pasteboard: NSPasteboard) -> Data? {
        guard pasteboard.types?.contains(.fileURL) != true,
              let imageType = pasteboard.availableType(from: [.png, .tiff]) else {
            return nil
        }
        return pasteboard.data(forType: imageType)
    }

    /// Shows one warning for the clipboard content at `changeCount` and counts it, when there are findings or SecChain
    /// matches. Not idempotent: each warning the system accepts is one more warning shown, which is what the metric
    /// counts.
    private func warnIfFound(
        textFindings: [Finding],
        imageFindings: [Finding],
        secChainLabels: [String],
        frontmostAppName: String?,
        changeCount: Int
    ) {
        guard !textFindings.isEmpty || !imageFindings.isEmpty || !secChainLabels.isEmpty else {
            return
        }
        // The app stays running across time zone changes, and `autoupdatingCurrent` is documented as "automatically
        // updating to the user's current preference":
        // https://developer.apple.com/documentation/foundation/timezone/autoupdatingcurrent
        let dayKey = WarningCounts.dayKey(date: Date(), timeZone: .autoupdatingCurrent)
        Task {
            // Only a warning the system accepted counts, because the metric counts warnings the user was shown.
            guard await WarningNotifier.post(
                textFindings: textFindings,
                imageFindings: imageFindings,
                secChainLabels: secChainLabels,
                frontmostAppName: frontmostAppName,
                dayKey: dayKey,
                changeCount: changeCount
            ) else {
                return
            }
            warningCountsByDay = WarningCountStore.recordWarning(defaults: .standard, dayKey: dayKey)
        }
    }

    /// Sets `accessState` only when it changed, because every assignment to an observed property re-renders the menu
    /// bar label and this runs on every poll.
    private func updateAccessState() {
        let currentAccessState = Self.currentAccessState()
        guard accessState != currentAccessState else {
            return
        }
        accessState = currentAccessState
    }

    /// Maps the pasteboard access behavior (macOS 15.4+) to whether a read may happen without an alert or denial.
    /// Source: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum
    /// ("The default behavior for the General pasteboard is to ask upon programmatic access").
    /// Before 15.4 there is no access control, so reads are always allowed.
    private static func currentAccessState() -> AccessState {
        guard #available(macOS 15.4, *) else {
            return .watching
        }
        switch NSPasteboard.general.accessBehavior {
        case .default, .alwaysAllow:
            return .watching
        case .ask, .alwaysDeny:
            return .needsPermission
        @unknown default:
            return .needsPermission
        }
    }
}
