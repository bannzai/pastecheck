import Foundation
import PasteCheckCore

/// Persists the per-day counts of `WarningCounts` in the app's `UserDefaults`.
///
/// Stored keys, each a dictionary from day (`yyyy-MM-dd`, local time) to a count:
/// - `warningCountsByDay`: warnings shown, one per notification (one per clipboard change with findings,
///   however many findings it had), because `documents/DIRECTION.md` counts "warnings shown".
/// - `falsePositiveCountsByDay`: warnings the user marked with "Not a secret", on the day the warning was shown.
///
/// The app is sandboxed, so these are written to the container at
/// `~/Library/Containers/com.bannzai.PasteCheck/Data/Library/Preferences/com.bannzai.PasteCheck.plist` and can be read
/// with `defaults read <that path> warningCountsByDay`. Only dates and numbers are stored, never clipboard content,
/// matched values, kinds, or positions (`documents/PROJECT.md` invariant 1).
enum WarningCountStore {
    static let warningsKey = "warningCountsByDay"
    static let falsePositivesKey = "falsePositiveCountsByDay"

    /// The stored warning counts, empty when nothing was recorded yet.
    static func warnings(defaults: UserDefaults) -> [String: Int] {
        defaults.dictionary(forKey: warningsKey) as? [String: Int] ?? [:]
    }

    /// Adds one warning on `dayKey` and returns the updated counts.
    /// Not idempotent: each call is one more warning shown, which is what the metric counts.
    @discardableResult
    static func recordWarning(defaults: UserDefaults, dayKey: String) -> [String: Int] {
        record(defaults: defaults, key: warningsKey, dayKey: dayKey)
    }

    /// Adds one false positive on `dayKey`.
    /// Not idempotent: each "Not a secret" press marks one more warning as a false positive.
    static func recordFalsePositive(defaults: UserDefaults, dayKey: String) {
        record(defaults: defaults, key: falsePositivesKey, dayKey: dayKey)
    }

    @discardableResult
    private static func record(defaults: UserDefaults, key: String, dayKey: String) -> [String: Int] {
        let counts = WarningCounts.incremented(
            counts: defaults.dictionary(forKey: key) as? [String: Int] ?? [:],
            dayKey: dayKey
        )
        defaults.set(counts, forKey: key)
        return counts
    }
}
