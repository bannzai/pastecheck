import AppKit

/// The places outside the app that the menu and the first-launch window open.
enum ExternalLinks {
    /// The support address published on the support page (`docs/support.md`) and required by `documents/PROJECT.md`
    /// "Features".
    static let contactSupportURL = URL(string: "mailto:bannzai.app@gmail.com")
    /// The privacy policy, served by GitHub Pages from `docs/privacy.md` (`permalink: /privacy/`).
    static let privacyPolicyURL = URL(string: "https://bannzai.github.io/pastecheck/privacy/")
    /// The terms of use, served by GitHub Pages from `docs/terms.md` (`permalink: /terms/`).
    static let termsURL = URL(string: "https://bannzai.github.io/pastecheck/terms/")
    /// The "Paste from Other Apps" page under Privacy & Security, the setting behind `NSPasteboard.accessBehavior`.
    /// Unverified: whether the `Pasteboard` anchor opens that page on macOS 15 (https://github.com/bannzai/pastecheck/issues/10 ).
    static let clipboardAccessSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Pasteboard"
    )
    /// The top of Privacy & Security in System Settings.
    static let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")

    /// Opens each of `urls` that is valid, in order.
    @MainActor
    static func open(urls: [URL?]) {
        for url in urls.compactMap(\.self) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the clipboard access setting, or the top of Privacy & Security when the URL cannot be opened at all.
    /// `NSWorkspace.open` returns `false` only when no app opens the URL; an anchor System Settings does not know still
    /// opens System Settings and returns `true`, so the fallback does not cover an unknown anchor.
    @MainActor
    static func openClipboardAccessSettings() {
        guard let clipboardAccessSettingsURL, NSWorkspace.shared.open(clipboardAccessSettingsURL) else {
            open(urls: [privacySettingsURL])
            return
        }
    }
}
