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
