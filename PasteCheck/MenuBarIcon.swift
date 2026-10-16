import SwiftUI

/// The menu bar icon. It tells the user the monitoring state without opening the menu.
///
/// It also opens the first-launch window until that window has been closed once. The icon is the only view an
/// `LSUIElement` app shows at every launch, so this does not depend on SwiftUI presenting the window scene by itself.
struct MenuBarIcon: View {
    let monitor: ClipboardMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: Self.symbolName(status: monitor.status))
            .onAppear {
                guard !monitor.hasCompletedOnboarding else {
                    return
                }
                openWindow(id: OnboardingView.windowID)
                NSApplication.shared.activate()
            }
    }

    /// The SF Symbol of `status`, as listed in `documents/design/app-icon/README.md`. A switch, so a new state cannot
    /// ship without its symbol.
    static func symbolName(status: ClipboardMonitor.Status) -> String {
        switch status {
        case .watching:
            return "checkmark.shield"
        case .paused:
            return "shield.slash"
        case .needsPermission, .setupNotFinished:
            return "exclamationmark.shield"
        }
    }
}
