import Foundation
import Testing
@testable import PasteCheckCore

@Test func dayKeyUsesTheGivenTimeZoneAndTheGregorianYear() throws {
    // 2026-10-11T16:00:00Z is already 2026-10-12 in Tokyo.
    let date = Date(timeIntervalSince1970: 1_791_734_400)

    #expect(WarningCounts.dayKey(date: date, timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))) == "2026-10-12")
    #expect(WarningCounts.dayKey(date: date, timeZone: try #require(TimeZone(identifier: "UTC"))) == "2026-10-11")
}

@Test func incrementedAddsANewDayAndRaisesAnExistingDay() {
    let counts = WarningCounts.incremented(counts: ["2026-10-11": 2], dayKey: "2026-10-12")

    #expect(counts == ["2026-10-11": 2, "2026-10-12": 1])
    #expect(WarningCounts.incremented(counts: counts, dayKey: "2026-10-11") == ["2026-10-11": 3, "2026-10-12": 1])
}

@Test func effectiveWarningsSubtractsFalsePositivesPerDayWithoutGoingNegative() {
    let warnings = ["2026-10-11": 3, "2026-10-12": 1, "2026-10-13": 5]
    let falsePositives = ["2026-10-11": 1, "2026-10-12": 2]

    #expect(
        WarningCounts.effectiveWarnings(
            warnings: warnings,
            falsePositives: falsePositives,
            dayKeys: ["2026-10-11", "2026-10-12"]
        ) == 2
    )
}
