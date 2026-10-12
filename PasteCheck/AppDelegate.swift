import AppKit
import UserNotifications

/// Receives the warning notification's callbacks. It is set as the notification center delegate at launch so that
/// actions pressed while the app was not running are still delivered.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        WarningNotifier.configure()
    }

    /// Shows the banner even though a menu bar app counts as the active app while its menu is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Hands the chosen action to `WarningNotifier`. Only Sendable values cross to the main actor, because
    /// `UNNotificationResponse` is not Sendable.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let dayKey = response.notification.request.content.userInfo[WarningNotifier.dayKeyUserInfoKey] as? String
        await MainActor.run {
            WarningNotifier.handle(actionIdentifier: actionIdentifier, dayKey: dayKey)
        }
    }
}
