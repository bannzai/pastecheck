import SwiftUI

@main
struct PasteCheckApp: App {
    var body: some Scene {
        MenuBarExtra("PasteCheck", systemImage: "doc.on.clipboard") {
            Text("準備中")
            Divider()
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
