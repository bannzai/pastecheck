import Testing
@testable import PasteCheckCore

@Test func apiKeysAndTokensGroupsTheFourTokenFormats() {
    #expect(DetectionCategory.apiKeysAndTokens.kinds == [.awsAccessKeyID, .githubToken, .openAIKey, .slackToken])
}

@Test func defaultsKeysStayTheStoredNames() {
    // The stored names users' checkboxes live under (`documents/DIRECTION.md` "決めたこと", 2026-10-16).
    #expect(
        DetectionCategory.allCases.map(\.defaultsKey) == [
            "detectsApiKeysAndTokens",
            "detectsPrivateKeys",
            "detectsJwt",
            "detectsCreditCardNumbers",
            "detectsEnvAssignments",
        ]
    )
}

@Test func everyKindBelongsToExactlyOneCategory() {
    let kindsPerCategory = DetectionCategory.allCases.map(\.kinds)

    #expect(kindsPerCategory.reduce(Set<SecretKind>()) { $0.union($1) } == Set(SecretKind.allCases))
    #expect(kindsPerCategory.map(\.count).reduce(0, +) == SecretKind.allCases.count)
}

@Test func findingsSkipTheKindsOfACategoryThatIsOff() {
    // The jwt.io sample token, split so secret scanning does not flag the source
    // (`.claude/rules/clipboard-content-handling.md`).
    let jwt = "eyJhbGciOiJIUzI1NiIs" + "InR5cCI6IkpXVCJ9" + "." + "eyJzdWIiOiIxMjM0NTY3" + "ODkwIn0" + ".dummysignature"
    let text = "AKIA" + "IOSFODNN7EXAMPLE " + jwt
    let kindsWithoutJWT = Set(SecretKind.allCases).subtracting(DetectionCategory.jwt.kinds)

    #expect(SecretDetector.findings(in: text).map(\.kind) == [.awsAccessKeyID, .jwt])
    #expect(SecretDetector.findings(in: text, kinds: kindsWithoutJWT).map(\.kind) == [.awsAccessKeyID])
    #expect(SecretDetector.findings(in: text, kinds: []).isEmpty)
}
