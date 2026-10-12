import AppKit
import PasteCheckCore
import UserNotifications

/// Shows the warning notification and carries out its two actions.
///
/// The notification text comes from `WarningMessage` and holds only kinds and positions. The only extra data on the
/// notification is the day key used to count a "Not a secret" press, the pasteboard `changeCount` the warning was
/// about, and the launch it was posted in, never anything from the clipboard (`documents/PROJECT.md` invariant 1).
enum WarningNotifier {
    static let categoryIdentifier = "secretWarning"
    static let clearClipboardActionIdentifier = "clearClipboard"
    static let notASecretActionIdentifier = "notASecret"
    static let dayKeyUserInfoKey = "dayKey"
    static let changeCountUserInfoKey = "changeCount"
    static let launchIDUserInfoKey = "launchID"
    /// Identifies this run of the app. A `changeCount` from an earlier run can equal the current one by coincidence
    /// (for example after the Mac restarts), so a warning left in Notification Center from an earlier run must not
    /// clear the clipboard.
    static let launchID = UUID().uuidString

    /// Registers the warning's actions and asks for permission to notify. Safe to call on every launch: the system
    /// replaces the categories and only asks the user once.
    @MainActor
    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: categoryIdentifier,
                actions: [
                    UNNotificationAction(identifier: clearClipboardActionIdentifier, title: "Clear clipboard"),
                    UNNotificationAction(identifier: notASecretActionIdentifier, title: "Not a secret"),
                ],
                intentIdentifiers: []
            ),
        ])
        Task {
            // A denial is not an error to surface here: the warning simply cannot be shown, and the user can turn
            // notifications on in System Settings.
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Shows one warning for the clipboard content at `changeCount`.
    /// - Returns: Whether the system accepted the notification. It is `false` when notifications are off for PasteCheck
    ///   (`UNError.notificationsNotAllowed`), in which case no warning was shown and the caller must not count one.
    ///   Source: https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed
    ///   ("This error occurs when you try to submit a notification request and your app or app extension isn't
    ///   authorized to schedule notifications").
    @MainActor
    static func post(
        findings: [Finding],
        inspectedContent: InspectedContent,
        frontmostAppName: String?,
        dayKey: String,
        changeCount: Int
    ) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = WarningMessage.title(findings: findings)
        content.body = WarningMessage.body(
            findings: findings,
            inspectedContent: inspectedContent,
            frontmostAppName: frontmostAppName
        )
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [dayKeyUserInfoKey: dayKey, changeCountUserInfoKey: changeCount, launchIDUserInfoKey: launchID]
        content.sound = .default
        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
            return true
        } catch {
            return false
        }
    }

    /// Carries out the action the user chose on a warning. The clipboard is changed only here, by an explicit
    /// "Clear clipboard" press, never automatically (`documents/PROJECT.md` invariant 2), and only while it still holds
    /// the content the warning was about: after another copy the old warning must not erase the new content.
    /// Not idempotent: each "Not a secret" press adds one false positive.
    @MainActor
    static func handle(actionIdentifier: String, dayKey: String?, changeCount: Int?, launchID: String?) {
        switch actionIdentifier {
        case clearClipboardActionIdentifier:
            guard launchID == Self.launchID, let changeCount, NSPasteboard.general.changeCount == changeCount else {
                return
            }
            NSPasteboard.general.clearContents()
        case notASecretActionIdentifier:
            guard let dayKey else {
                return
            }
            WarningCountStore.recordFalsePositive(defaults: .standard, dayKey: dayKey)
        default:
            return
        }
    }
}
