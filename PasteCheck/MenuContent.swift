import PasteCheckCore
import SwiftUI

/// The menu bar menu: the monitoring state at the top (the status part of
/// `documents/design/mock-2026-10-11/Main.dc.html`) and Quit. Settings rows come in a later change.
struct MenuContent: View {
    let monitor: ClipboardMonitor

    var body: some View {
        switch monitor.accessState {
        case .watching:
            Text("Watching the clipboard")
        case .needsPermission:
            Text("Clipboard access needed")
            Text("Allow PasteCheck to read the clipboard in System Settings")
        }
        Text("Last check: \(monitor.lastCheckedAt?.formatted(date: .omitted, time: .standard) ?? "none yet")")
        Text("Warnings today: \(monitor.warningCountsByDay[WarningCounts.dayKey(date: Date(), timeZone: .autoupdatingCurrent)] ?? 0)")
        Divider()
        Button("Quit PasteCheck") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
