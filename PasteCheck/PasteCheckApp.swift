import SwiftUI

/// The entry point of an app that lives only in the menu bar. It has no windows (`LSUIElement` in Info.plist);
/// clipboard monitoring runs from launch and is controlled from the menu bar.
@main
struct PasteCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            // The icon itself tells the user when clipboard access is needed, without opening the menu.
            Image(systemName: monitor.accessState == .watching ? "checkmark.shield" : "exclamationmark.shield")
        }
    }
}
