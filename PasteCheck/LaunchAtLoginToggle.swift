import ServiceManagement
import SwiftUI

/// The "Launch at login" checkbox, which registers the app itself as a login item with `SMAppService.mainApp`
/// (https://developer.apple.com/documentation/servicemanagement/smappservice ).
///
/// The system owns the login item (the user can also remove it in System Settings > General > Login Items), so the
/// checkbox shows `SMAppService.mainApp.status`, read again after every change and whenever the menu appears, instead of
/// a value stored by the app. A failed registration therefore shows as the checkbox staying off.
struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        MenuCheckboxRow(
            title: "Launch at login",
            isOn: Binding(
                get: { isEnabled },
                set: { update(isEnabled: $0) }
            )
        )
        .onAppear {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    /// Registers or unregisters the login item, then shows the resulting status. When macOS wants the user to approve
    /// the item, its page in System Settings is opened, because the checkbox cannot turn on until then.
    private func update(isEnabled newIsEnabled: Bool) {
        do {
            if newIsEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Not shown: the checkbox below goes back to the real status, which is the result the user sees.
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
