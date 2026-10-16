import SwiftUI

/// The first-launch window (`documents/design/mock-2026-10-11/Onboarding.dc.html`). It explains the two permissions
/// PasteCheck needs and lets the user trigger each prompt. The SecChain step of the mock comes with
/// https://github.com/bannzai/pastecheck/issues/14 .
///
/// Closing the window by any means, "Start watching" or the close button, starts inspecting and keeps the window from
/// opening at the next launch. Making only one button count would leave a user who closed it with nothing watched.
struct OnboardingView: View {
    /// The id of the `Window` scene that shows this view.
    static let windowID = "onboarding"

    let monitor: ClipboardMonitor
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PasteCheck watches what you copy and warns you before you paste a secret. Everything stays on this Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // macOS's alert wording is unverified (https://github.com/bannzai/pastecheck/issues/5 , PR #4 review), so the
            // body names the outcome rather than a button label. A one-time allow leaves the access behavior at "ask",
            // where PasteCheck stops reading (`documents/DIRECTION.md` "決めたこと", 2026-10-12), hence "always".
            OnboardingStepRow(
                title: "Allow clipboard access",
                detail: "macOS asks when PasteCheck first reads the clipboard. Choose the option that always allows it there, or allow it later in System Settings under Privacy & Security.",
                actionTitle: "Allow"
            ) {
                monitor.requestAccess()
            }
            OnboardingStepRow(
                title: "Allow notifications",
                detail: "Warnings arrive as notifications. They name the kind of secret and where it sits, never the value itself.",
                actionTitle: "Allow"
            ) {
                WarningNotifier.requestAuthorization()
            }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button("How PasteCheck handles your clipboard") {
                    ExternalLinks.open(urls: [ExternalLinks.privacyPolicyURL])
                }
                .buttonStyle(.link)
                .font(.callout)
                Spacer()
                Button("Start watching") {
                    monitor.completeOnboarding()
                    dismissWindow(id: Self.windowID)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        // A menu bar app is not active by itself, so the window would otherwise open behind the frontmost app, also
        // when SwiftUI presents it at launch.
        .onAppear {
            NSApplication.shared.activate()
        }
        // Also covers the close button. "Start watching" completes onboarding before dismissing as well, so starting
        // does not depend on this callback alone.
        .onDisappear {
            monitor.completeOnboarding()
        }
    }
}

/// One permission in the first-launch window: what it is for, and a button that brings up its prompt.
private struct OnboardingStepRow: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(actionTitle, action: action)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }
}
