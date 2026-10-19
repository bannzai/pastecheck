import Foundation
import Testing
@testable import PasteCheckCore

@Test func noOutputMeansNoMatch() {
    #expect(SecChainMatch.outcome(terminationStatus: 0, terminatedBySignal: false, standardOutput: Data()) == .matched(labels: []))
}

@Test func eachLineIsOneMatchedSecret() {
    let output = Data("DUMMY_TOKEN (scope user)\nDUMMY_TOKEN (github.com/owner/repo, environment prod)\n".utf8)

    #expect(
        SecChainMatch.outcome(terminationStatus: 0, terminatedBySignal: false, standardOutput: output)
            == .matched(labels: ["DUMMY_TOKEN (scope user)", "DUMMY_TOKEN (github.com/owner/repo, environment prod)"])
    )
}

@Test func lastLineWithoutNewlineStillCounts() {
    #expect(
        SecChainMatch.outcome(terminationStatus: 0, terminatedBySignal: false, standardOutput: Data("DUMMY_TOKEN (scope user)".utf8))
            == .matched(labels: ["DUMMY_TOKEN (scope user)"])
    )
}

@Test func nonZeroExitIsAFailure() {
    #expect(SecChainMatch.outcome(terminationStatus: 1, terminatedBySignal: false, standardOutput: Data()) == .failed)
}

@Test func killedProcessIsAFailureEvenWithOutput() {
    // SIGTERM, which PasteCheck sends on its timeout. A partial answer is not trusted.
    #expect(
        SecChainMatch.outcome(terminationStatus: 15, terminatedBySignal: true, standardOutput: Data("DUMMY_TOKEN (scope user)\n".utf8))
            == .failed
    )
}

@Test func onlyAMatchHasLabelsToWarnAbout() {
    #expect(SecChainMatchOutcome.matched(labels: ["DUMMY_TOKEN (scope user)"]).matchedLabels == ["DUMMY_TOKEN (scope user)"])
    #expect(SecChainMatchOutcome.notInstalled.matchedLabels.isEmpty)
    #expect(SecChainMatchOutcome.failed.matchedLabels.isEmpty)
}

@Test func outputThatIsNotUTF8IsAFailure() {
    #expect(SecChainMatch.outcome(terminationStatus: 0, terminatedBySignal: false, standardOutput: Data([0xFF, 0xFE, 0x0A])) == .failed)
}
