import Foundation
import PasteCheckCore

/// Persists the "Detect" checkboxes of the menu in the app's `UserDefaults`, one `Bool` per `DetectionCategory` under
/// `DetectionCategory.defaultsKey`. Only on/off flags are stored, never clipboard content
/// (`documents/PROJECT.md` invariant 1).
enum DetectionSettingsStore {
    /// The value of a checkbox the user never touched. On, because every category is an MVP detection
    /// (`documents/DIRECTION.md` "必要な機能") and the checkbox exists to turn one off after false positives.
    static let defaultIsEnabled = true

    /// Whether `category`'s checkbox is on.
    static func isEnabled(defaults: UserDefaults, category: DetectionCategory) -> Bool {
        defaults.object(forKey: category.defaultsKey) as? Bool ?? defaultIsEnabled
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
