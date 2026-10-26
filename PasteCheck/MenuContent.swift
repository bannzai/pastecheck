import PasteCheckCore
import SwiftUI

/// The menu bar panel, in the order of `documents/design/mock-2026-10-11/Main.dc.html` (watching) and
/// `MenuPaused.dc.html` (paused). The mock's rows for matching saved secrets are not built, because that matching was
/// removed (`documents/DIRECTION.md` "決めたこと", 2026-10-27), and OCR has no row because it has no setting
/// (`documents/DIRECTION.md` "決めたこと", 2026-10-13).
struct MenuContent: View {
    let monitor: ClipboardMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            MenuDivider()
            if monitor.status == .paused {
                Text("Nothing you copy is checked while paused. Resume before you paste anything you are unsure about.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.45)))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                MenuButtonRow(title: "Resume now", shortcutHint: "⌘P", isProminent: true) {
                    monitor.updatePause(pause: .notPaused)
                }
                .keyboardShortcut("p")
            } else {
                VStack(spacing: 6) {
                    MenuValueRow(
                        title: "Last check",
                        value: monitor.lastCheckedAt?.formatted(date: .omitted, time: .standard) ?? "None yet"
                    )
                    MenuValueRow(
                        title: "Warnings today",
                        value: "\(monitor.warningCountsByDay[WarningCounts.dayKey(date: Date(), timeZone: .autoupdatingCurrent)] ?? 0)"
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                MenuDivider()
                MenuButtonRow(title: "Pause for 10 minutes", shortcutHint: "⌘P") {
                    monitor.updatePause(pause: .until(Date().addingTimeInterval(Pause.shortDuration)))
                }
                .keyboardShortcut("p")
                MenuButtonRow(title: "Pause until I resume") {
                    monitor.updatePause(pause: .untilResumed)
                }
            }
            MenuDivider()
            Text("Detect")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            ForEach(DetectionCategory.allCases, id: \.self) { category in
                DetectionCategoryRow(category: category)
            }
            .disabled(monitor.status == .paused)
            MenuDivider()
            LaunchAtLoginToggle()
            MenuDivider()
            MenuButtonRow(title: "Contact support") {
                ExternalLinks.open(urls: [ExternalLinks.contactSupportURL])
            }
            MenuButtonRow(title: "Privacy policy and terms") {
                ExternalLinks.open(urls: [ExternalLinks.privacyPolicyURL, ExternalLinks.termsURL])
            }
            MenuButtonRow(title: "Show welcome window") {
                openOnboardingWindow()
            }
            MenuDivider()
            MenuButtonRow(title: "Quit PasteCheck", shortcutHint: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(6)
        .frame(width: 320)
    }

    /// The app name and the monitoring state, with a row that leads to the fix when inspection cannot run.
    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: MenuBarIcon.symbolName(status: monitor.status))
                .font(.title2)
                .foregroundStyle(monitor.status == .paused ? .secondary : .primary)
            VStack(alignment: .leading, spacing: 1) {
                Text("PasteCheck")
                    .fontWeight(.semibold)
                // Redrawn every second so the minutes left in a timed pause count down while the panel is open.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    statusText(now: context.date)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        switch monitor.status {
        case .setupNotFinished:
            MenuButtonRow(title: "Finish setup") {
                openOnboardingWindow()
            }
        case .needsPermission:
            MenuButtonRow(title: "Allow clipboard access in System Settings") {
                ExternalLinks.openClipboardAccessSettings()
            }
        case .paused, .watching:
            EmptyView()
        }
    }

    /// The one-line state under the app name.
    private func statusText(now: Date) -> Text {
        switch monitor.status {
        case .setupNotFinished:
            return Text("Setup not finished")
                .foregroundStyle(.secondary)
        case .paused:
            guard let remainingMinutes = monitor.pause.remainingMinutes(now: now) else {
                return Text("Paused until you resume")
                    .foregroundStyle(.orange)
            }
            return Text("Paused · resumes in \(remainingMinutes) min")
                .foregroundStyle(.orange)
        case .needsPermission:
            return Text("Clipboard access needed")
                .foregroundStyle(.orange)
        case .watching:
            return Text("Watching the clipboard")
                .foregroundStyle(.green)
        }
    }

    /// Shows the first-launch window in front. A menu bar app is not active by itself, so without activating the window
    /// would open behind the frontmost app.
    private func openOnboardingWindow() {
        openWindow(id: OnboardingView.windowID)
        NSApplication.shared.activate()
    }
}
