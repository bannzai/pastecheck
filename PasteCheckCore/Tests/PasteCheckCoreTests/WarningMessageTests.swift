import Testing
@testable import PasteCheckCore

private let text = "x"

private func finding(kind: SecretKind, line: Int, column: Int, length: Int) -> Finding {
    Finding(kind: kind, range: text.startIndex..<text.endIndex, line: line, column: column, length: length)
}

@Test func titleNamesTheOnlyKind() {
    let findings = [finding(kind: .githubToken, line: 3, column: 1, length: 40)]

    #expect(WarningMessage.title(findings: findings) == "Looks like a GitHub token")
}

@Test func titleCountsOtherKinds() {
    let findings = [
        finding(kind: .githubToken, line: 1, column: 1, length: 40),
        finding(kind: .githubToken, line: 2, column: 1, length: 40),
        finding(kind: .jwt, line: 3, column: 1, length: 100),
        finding(kind: .creditCardNumber, line: 4, column: 1, length: 19),
    ]

    #expect(WarningMessage.title(findings: findings) == "Looks like a GitHub token and 2 more kinds of secrets")
}

@Test func bodyHasPositionAndFrontmostApp() {
    let findings = [finding(kind: .githubToken, line: 3, column: 5, length: 40)]

    #expect(
        WarningMessage.body(textFindings: findings, imageFindings: [], frontmostAppName: "Terminal")
            == "Line 3, column 5, 40 characters, while Terminal was in front. PasteCheck did not change the clipboard."
    )
}

@Test func bodyForImageHasNoLineOrColumn() {
    let findings = [
        finding(kind: .awsAccessKeyID, line: 2, column: 7, length: 20),
        finding(kind: .githubToken, line: 4, column: 1, length: 40),
    ]

    #expect(
        WarningMessage.body(textFindings: [], imageFindings: findings, frontmostAppName: "Preview")
            == "In the copied image (and 1 more match), while Preview was in front. PasteCheck did not change the clipboard."
    )
}

@Test func bodyForTextAndImageIsOneWarning() {
    let textFindings = [finding(kind: .githubToken, line: 3, column: 5, length: 40)]
    let imageFindings = [finding(kind: .githubToken, line: 1, column: 1, length: 40)]

    #expect(
        WarningMessage.body(textFindings: textFindings, imageFindings: imageFindings, frontmostAppName: "Keynote")
            == "Line 3, column 5, 40 characters, also in the copied image (and 1 more match), while Keynote was in front. PasteCheck did not change the clipboard."
    )
}

@Test func secChainTitleForOneSecret() {
    #expect(WarningMessage.secChainTitle(matchedLabels: ["DUMMY_TOKEN (scope user)"]) == "Your clipboard holds a secret saved in SecChain")
}

@Test func secChainTitleCountsSecrets() {
    #expect(
        WarningMessage.secChainTitle(matchedLabels: ["DUMMY_TOKEN (scope user)", "OTHER_DUMMY (scope user)"])
            == "Your clipboard holds 2 secrets saved in SecChain"
    )
}

@Test func secChainBodyNamesTheSecretAndFrontmostApp() {
    #expect(
        WarningMessage.secChainBody(matchedLabels: ["DUMMY_TOKEN (github.com/owner/repo)"], imageFindings: [], frontmostAppName: "Terminal")
            == "Contains the value of DUMMY_TOKEN (github.com/owner/repo), while Terminal was in front. This is your real secret, not a look-alike. PasteCheck did not change the clipboard."
    )
}

@Test func secChainBodyCountsOtherSecretsAndLeavesOutUnknownApp() {
    #expect(
        WarningMessage.secChainBody(
            matchedLabels: ["DUMMY_TOKEN (scope user)", "OTHER_DUMMY (scope user)", "THIRD_DUMMY (scope user)"],
            imageFindings: [],
            frontmostAppName: nil
        )
            == "Contains the value of DUMMY_TOKEN (scope user) and 2 more saved secrets. This is your real secret, not a look-alike. PasteCheck did not change the clipboard."
    )
}

@Test func secChainBodyCountsLookAlikesInTheImage() {
    let imageFindings = [
        finding(kind: .awsAccessKeyID, line: 1, column: 1, length: 20),
        finding(kind: .githubToken, line: 2, column: 1, length: 40),
    ]

    #expect(
        WarningMessage.secChainBody(matchedLabels: ["DUMMY_TOKEN (scope user)"], imageFindings: imageFindings, frontmostAppName: nil)
            == "Contains the value of DUMMY_TOKEN (scope user). This is your real secret, not a look-alike. The copied image also holds 2 look-alikes. PasteCheck did not change the clipboard."
    )
    #expect(
        WarningMessage.secChainBody(matchedLabels: ["DUMMY_TOKEN (scope user)"], imageFindings: [imageFindings[0]], frontmostAppName: nil)
            == "Contains the value of DUMMY_TOKEN (scope user). This is your real secret, not a look-alike. The copied image also holds 1 look-alike. PasteCheck did not change the clipboard."
    )
}

@Test func bodyLeavesOutUnknownAppAndCountsOtherMatches() {
    let findings = [
        finding(kind: .githubToken, line: 1, column: 1, length: 40),
        finding(kind: .jwt, line: 2, column: 1, length: 100),
    ]

    #expect(
        WarningMessage.body(textFindings: findings, imageFindings: [], frontmostAppName: nil)
            == "Line 1, column 1, 40 characters (and 1 more match). PasteCheck did not change the clipboard."
    )
}
