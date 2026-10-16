import SwiftUI

/// The entry point of an app that lives only in the menu bar (`LSUIElement` in Info.plist). Clipboard monitoring is
/// controlled from the menu bar panel; the only window is the first-launch window.
@main
struct PasteCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            MenuBarIcon(monitor: monitor)
        }
        // A panel rather than a menu, because the paused state is shown as a colored band
        // (`documents/design/mock-2026-10-11/MenuPaused.dc.html`), which a menu cannot draw.
        .menuBarExtraStyle(.window)
        Window("Welcome to PasteCheck", id: OnboardingView.windowID) {
            OnboardingView(monitor: monitor)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(monitor.hasCompletedOnboarding ? .suppressed : .presented)
        // Restoring the window at launch would bring it back after setup; it opens only from the code above and the menu.
        .restorationBehavior(.disabled)
    }
}
