import Foundation
import Testing
@testable import PasteCheckCore

private let start = Date(timeIntervalSince1970: 1_791_734_400)

@Test func aTimedPauseEndsAtItsDate() {
    let pause = Pause.until(start.addingTimeInterval(Pause.shortDuration))

    #expect(pause.isActive(now: start))
    #expect(pause.isActive(now: start.addingTimeInterval(Pause.shortDuration - 1)))
    #expect(!pause.isActive(now: start.addingTimeInterval(Pause.shortDuration)))
}

@Test func pauseUntilResumedNeverEndsAndNotPausedIsNeverActive() {
    #expect(Pause.untilResumed.isActive(now: start.addingTimeInterval(365 * 24 * 60 * 60)))
    #expect(!Pause.notPaused.isActive(now: start))
}

@Test func remainingMinutesRoundUpAndAreNilOnceTheTimedPauseEnds() {
    let pause = Pause.until(start.addingTimeInterval(Pause.shortDuration))

    #expect(pause.remainingMinutes(now: start) == 10)
    #expect(pause.remainingMinutes(now: start.addingTimeInterval(3 * 60 - 1)) == 8)
    #expect(pause.remainingMinutes(now: start.addingTimeInterval(Pause.shortDuration - 1)) == 1)
    #expect(pause.remainingMinutes(now: start.addingTimeInterval(Pause.shortDuration)) == nil)
    #expect(Pause.untilResumed.remainingMinutes(now: start) == nil)
    #expect(Pause.notPaused.remainingMinutes(now: start) == nil)
}
