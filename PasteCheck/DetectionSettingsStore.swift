import Foundation
import PasteCheckCore

/// Persists the "Detect" checkboxes of the menu in the app's `UserDefaults`, one `Bool` per `DetectionCategory` under
/// `DetectionCategory.defaultsKey` and one for "SecChain secrets". Only on/off flags are stored, never clipboard content
/// (`documents/PROJECT.md` invariant 1).
enum DetectionSettingsStore {
    /// The value of a checkbox the user never touched. On, because every category is an MVP detection
    /// (`documents/DIRECTION.md` "必要な機能") and the checkbox exists to turn one off after false positives.
    static let defaultIsEnabled = true

    /// Whether `category`'s checkbox is on.
    static func isEnabled(defaults: UserDefaults, category: DetectionCategory) -> Bool {
        defaults.object(forKey: category.defaultsKey) as? Bool ?? defaultIsEnabled
    }

    /// The `UserDefaults` key of the "SecChain secrets" checkbox. No dots, for the same KVO reason as
    /// `DetectionCategory.defaultsKey`.
    static let matchesSecChainSecretsKey = "matchesSecChainSecrets"
    /// The value of the "SecChain secrets" checkbox the user never touched. Off, unlike the pattern checkboxes: with it
    /// on, clipboard text is handed to another process, the one exception to `documents/PROJECT.md` invariant 1, so
    /// that starts only when the user links SecChain ("Link" in the first-launch window, or this checkbox).
    static let defaultMatchesSecChainSecrets = false

    /// Whether the "SecChain secrets" checkbox is on. Read for each clipboard change, like `enabledKinds(defaults:)`.
    static func matchesSecChainSecrets(defaults: UserDefaults) -> Bool {
        defaults.object(forKey: matchesSecChainSecretsKey) as? Bool ?? defaultMatchesSecChainSecrets
    }

    /// The kinds to pass to `SecretDetector`. Read for each clipboard change, so a checkbox change applies from the
    /// next copy.
    static func enabledKinds(defaults: UserDefaults) -> Set<SecretKind> {
        Set(
            DetectionCategory.allCases
                .filter { isEnabled(defaults: defaults, category: $0) }
                .flatMap(\.kinds)
        )
    }
}
