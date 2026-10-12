import Testing
@testable import PasteCheckCore

@Test func inspectableTextPutsEachRegionOnItsOwnLine() {
    #expect(RecognizedText.inspectableText(lines: ["first", "second"]) == "first\nsecond")
}

@Test func inspectableTextIsEmptyWithoutRecognizedLines() {
    #expect(RecognizedText.inspectableText(lines: []) == "")
}

@Test func lineAnchoredRuleMatchesARegionNextToOtherRegions() {
    // `.env` style lines are anchored to the line start and end, so this fails if the regions were joined by a space.
    let lines = ["Settings", "API" + "_TOKEN=" + "dummyValue1234567890abc", "Saved"]

    let findings = SecretDetector.findings(in: RecognizedText.inspectableText(lines: lines))

    #expect(findings.map(\.kind) == [.envAssignment])
}
