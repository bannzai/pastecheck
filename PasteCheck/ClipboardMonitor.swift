import AppKit
import Observation
import PasteCheckCore

/// Watches the general pasteboard, inspects new text with `SecretDetector`, and warns through `WarningNotifier`.
/// Holds the state shown at the top of the menu.
///
/// The clipboard text lives only in a local inside `inspectIfChanged()` and is never stored, logged or sent anywhere
/// (`documents/PROJECT.md` invariant 1).
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

    /// AppKit has no change notification for the pasteboard, so `changeCount` is polled. Half a second is short
    /// enough that a warning arrives before a typical copy-switch-paste, and comparing one integer that often costs
    /// next to nothing.
    static let pollingInterval: Duration = .milliseconds(500)

    private(set) var accessState: AccessState
    /// When new clipboard text was last inspected; `nil` until the first change after launch.
    private(set) var lastCheckedAt: Date?
    /// The stored per-day warning counts, refreshed whenever a warning is recorded.
    private(set) var warningCountsByDay: [String: Int]

    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    /// Starts polling at once. Whatever was already on the clipboard at launch is not read, so launching never
    /// triggers the macOS clipboard access alert by itself.
    init() {
        accessState = Self.currentAccessState()
        warningCountsByDay = WarningCountStore.warnings(defaults: .standard)
        lastChangeCount = NSPasteboard.general.changeCount
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollingInterval)
                self?.inspectIfChanged()
            }
        }
    }

    /// Reads and inspects the clipboard once per `changeCount` change. Reading only on a change, and not at all while
    /// access would ask or deny, keeps macOS from showing its access alert again and again.
    private func inspectIfChanged() {
        // Refreshed on every poll, not only on a clipboard change, so allowing access in System Settings updates the
        // icon right away. While access is needed, `lastChangeCount` is left alone, so the content copied in the
        // meantime is inspected as soon as access is allowed.
        updateAccessState()
        let pasteboard = NSPasteboard.general
        guard accessState == .watching, pasteboard.changeCount != lastChangeCount else {
            return
        }
        let changeCount = pasteboard.changeCount
        let text = pasteboard.string(forType: .string)
        // Another copy during the read would pair new text with the old count, which double-counts the warning and
        // makes "Clear clipboard" a no-op, so that read is dropped and retried on the next poll.
        guard pasteboard.changeCount == changeCount else {
            return
        }
        // The first read in the `.default` behavior shows the system alert, after which the behavior becomes `.ask`
        // or whatever the user picked, so it is read again for the menu.
        updateAccessState()
        // A read the user denied in that alert is left unprocessed, so the content is inspected once access is allowed.
        guard text != nil || accessState == .watching else {
            return
        }
        lastChangeCount = changeCount
        lastCheckedAt = Date()
        // `nil` also means the clipboard holds no text (an image or files), which is not a permission problem.
        guard let text else {
            return
        }
        let findings = SecretDetector.findings(in: text)
        guard !findings.isEmpty else {
            return
        }
        let dayKey = WarningCounts.dayKey(date: Date(), timeZone: .current)
        let frontmostAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        let changeCount = lastChangeCount
        Task {
            // Only a warning the system accepted counts, because the metric counts warnings the user was shown.
            guard await WarningNotifier.post(
                findings: findings,
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
