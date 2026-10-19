import PasteCheckCore
import SwiftUI

// The rows the menu panel is built from, laid out after `documents/design/mock-2026-10-11/Main.dc.html`: label on the
// left, checkbox or shortcut on the right, 6 points of rounded hover highlight like a macOS menu item.

/// A full-width row that runs `action` on click, with an optional shortcut hint on the right. The hint is drawn as text
/// because `.keyboardShortcut` shows nothing outside a real menu.
struct MenuButtonRow: View {
    let title: String
    var shortcutHint: String?
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcutHint {
                    Text(shortcutHint)
                        .font(.caption)
                        .foregroundStyle(isProminent ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle(isProminent: isProminent))
    }
}

/// The look of `MenuButtonRow`: plain with a highlight on hover, or filled with the accent color when prominent
/// ("Resume now" in `documents/design/mock-2026-10-11/MenuPaused.dc.html`).
struct MenuRowButtonStyle: ButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        MenuRowButtonBody(configuration: configuration, isProminent: isProminent)
    }
}

/// The view behind `MenuRowButtonStyle`, separate because tracking the hover needs view state.
private struct MenuRowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .fontWeight(isProminent ? .semibold : nil)
            .foregroundStyle(isProminent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
            .onHover { isHovered = $0 }
    }

    private var background: AnyShapeStyle {
        if isProminent {
            return AnyShapeStyle(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1))
        }
        return isHovered || configuration.isPressed ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)
    }
}

/// A row with a label on the left and a checkbox on the right.
struct MenuCheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
        .toggleStyle(MenuCheckboxToggleStyle())
    }
}

/// Puts the checkbox of a `Toggle` on the right edge of the row, as in the mock.
private struct MenuCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 26)
    }
}

/// The "Detect" checkbox of `category`, stored by `DetectionSettingsStore`.
struct DetectionCategoryRow: View {
    let category: DetectionCategory
    @AppStorage private var isEnabled: Bool

    init(category: DetectionCategory) {
        self.category = category
        _isEnabled = AppStorage(
            wrappedValue: DetectionSettingsStore.defaultIsEnabled,
            category.defaultsKey
        )
    }

    var body: some View {
        MenuCheckboxRow(title: category.title, isOn: $isEnabled)
    }
}

/// The "SecChain secrets" checkbox under "Detect", stored by `DetectionSettingsStore`. Not disabled while SecChain is
/// missing, so it can be turned on before SecChain is installed; the "SecChain" row then says "Not installed".
struct SecChainSecretsRow: View {
    let monitor: ClipboardMonitor
    @AppStorage(DetectionSettingsStore.matchesSecChainSecretsKey)
    private var matchesSecChainSecrets = DetectionSettingsStore.defaultMatchesSecChainSecrets

    var body: some View {
        MenuCheckboxRow(title: "SecChain secrets", isOn: $matchesSecChainSecrets)
            .onChange(of: matchesSecChainSecrets) {
                monitor.forgetSecChainMatch()
            }
            // `confirm` and `device-bound` secrets ask for authentication on every read, which would interrupt the user
            // on every copy, so `secchain match` skips them, and values shorter than 8 characters or made of whitespace
            // only, which occur in unrelated text (https://github.com/bannzai/SecChain/pull/92 , `SecretMask.isLookedFor`).
            .help("Warns when the value of a secret saved in SecChain is copied. Only secrets at the standard protection level with values of 8 or more characters are matched.")
    }
}

/// The "SecChain" row under the status: whether copies are matched against SecChain, and when not, why.
struct SecChainStatusRow: View {
    let monitor: ClipboardMonitor
    @AppStorage(DetectionSettingsStore.matchesSecChainSecretsKey)
    private var matchesSecChainSecrets = DetectionSettingsStore.defaultMatchesSecChainSecrets

    var body: some View {
        // Redrawn every second while the panel is open, because nothing tells the app that SecChain was installed or
        // removed.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            MenuValueRow(title: "SecChain", value: value)
        }
    }

    private var value: String {
        if !matchesSecChainSecrets {
            return "Off"
        }
        if !SecChainMatcher.isInstalled {
            return "Not installed"
        }
        switch monitor.lastSecChainMatchAnswered {
        case true?:
            return "Linked"
        case false?:
            // Fail open: the copy was still checked against the patterns, so the row says what is missing, not that
            // nothing was checked.
            return "Could not match, patterns only"
        case nil:
            // "Linked" only after SecChain answered, because a tool that fails its signature check or cannot read the
            // Keychain is found out on the first copied text.
            return "On, waiting for a copy"
        }
    }
}

/// A row with a label on the left and a value on the right, for the counters under the status.
struct MenuValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

/// A separator between groups of rows.
struct MenuDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
    }
}
