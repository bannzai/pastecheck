import Foundation

/// The per-day counters behind the "Warnings today" menu row and the `documents/DIRECTION.md` metric
/// "effective warnings" (warnings minus false positives).
///
/// Counts are keyed by local calendar day (`yyyy-MM-dd`) and hold numbers only: no clipboard content, matched
/// value, kind, or position is ever stored (`documents/PROJECT.md` invariant 1).
public enum WarningCounts {
    /// The key for the day of `date` in `timeZone`, e.g. `2026-10-12`. The Gregorian calendar and a fixed numeric format
    /// are used instead of the user's calendar and a `DateFormatter`, so a stored key does not change when the user
    /// switches to the Japanese or Buddhist calendar or another locale.
    public static func dayKey(date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// `counts` with the count of `dayKey` raised by one.
    public static func incremented(counts: [String: Int], dayKey: String) -> [String: Int] {
        counts.merging([dayKey: 1], uniquingKeysWith: +)
    }

    /// Warnings minus false positives over `dayKeys`. Never negative, so a stray extra "Not a secret" cannot
    /// make the metric look worse than zero.
    public static func effectiveWarnings(warnings: [String: Int], falsePositives: [String: Int], dayKeys: [String]) -> Int {
        dayKeys.reduce(0) { sum, dayKey in
            sum + max(0, (warnings[dayKey] ?? 0) - (falsePositives[dayKey] ?? 0))
        }
    }
}
