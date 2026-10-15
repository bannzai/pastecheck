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
            // The icon itself tells the user the monitoring state without opening the menu. The symbols per state,
            // including `shield.slash` for the paused state that the menu settings add, are listed in
            // `documents/design/app-icon/README.md`. A switch, so a new state cannot ship without its symbol.
            switch monitor.accessState {
            case .watching:
                Image(systemName: "checkmark.shield")
            case .needsPermission:
                Image(systemName: "exclamationmark.shield")
            }
        }
    }
}
