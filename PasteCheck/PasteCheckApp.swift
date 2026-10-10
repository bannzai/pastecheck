import SwiftUI

/// メニューバーだけに常駐するアプリの入口。ウィンドウは持たず (Info.plist の LSUIElement)、
/// クリップボードの監視と警告はメニューバーから操作する。
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
