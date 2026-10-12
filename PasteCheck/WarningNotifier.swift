import AppKit
import PasteCheckCore
import UserNotifications

/// Shows the warning notification and carries out its two actions.
///
/// The notification text comes from `WarningMessage` and holds only kinds and positions. The only extra data on the
/// notification is the day key used to count a "Not a secret" press, never anything from the clipboard
/// (`documents/PROJECT.md` invariant 1).
enum WarningNotifier {
    static let categoryIdentifier = "secretWarning"
    static let clearClipboardActionIdentifier = "clearClipboard"
    static let notASecretActionIdentifier = "notASecret"
    static let dayKeyUserInfoKey = "dayKey"

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

    /// Shows one warning for one clipboard change.
    @MainActor
    static func post(findings: [Finding], frontmostAppName: String?, dayKey: String) {
        let content = UNMutableNotificationContent()
        content.title = WarningMessage.title(findings: findings)
        content.body = WarningMessage.body(findings: findings, frontmostAppName: frontmostAppName)
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [dayKeyUserInfoKey: dayKey]
        content.sound = .default
        // A failure means notifications are off for PasteCheck; there is nothing else to show the warning with.
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }

    /// Carries out the action the user chose on a warning. The clipboard is changed only here, by an explicit
    /// "Clear clipboard" press, never automatically (`documents/PROJECT.md` invariant 2).
    /// Not idempotent: each "Not a secret" press adds one false positive.
    @MainActor
    static func handle(actionIdentifier: String, dayKey: String?) {
        switch actionIdentifier {
        case clearClipboardActionIdentifier:
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
