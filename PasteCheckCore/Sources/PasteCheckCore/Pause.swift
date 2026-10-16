import Foundation

/// Whether the user paused inspection from the menu, and until when. Nothing copied while paused is inspected.
public enum Pause: Equatable, Sendable {
    /// Inspection runs.
    case notPaused
    /// Paused until the date, after which inspection resumes by itself.
    case until(Date)
    /// Paused until the user presses "Resume now".
    case untilResumed

    /// The length of "Pause for 10 minutes" (the row of `documents/design/mock-2026-10-11/Main.dc.html`). Long enough to
    /// copy and paste a few values the user already knows about, short enough that a forgotten pause ends by itself.
    public static let shortDuration: TimeInterval = 10 * 60

    /// Whether inspection is paused at `now`. A timed pause ends at its date.
    public func isActive(now: Date) -> Bool {
        switch self {
        case .notPaused:
            return false
        case .until(let date):
            return now < date
        case .untilResumed:
            return true
        }
    }

    /// The minutes left in a timed pause at `now`, rounded up so the last minute reads "1 min" rather than "0 min"
    /// while still paused.
    /// - Returns: `nil` when this is not a timed pause or it has ended.
    public func remainingMinutes(now: Date) -> Int? {
        guard case .until(let date) = self, now < date else {
            return nil
        }
        return Int((date.timeIntervalSince(now) / 60).rounded(.up))
    }
}
