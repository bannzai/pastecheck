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
        WarningMessage.body(findings: findings, inspectedContent: .text, frontmostAppName: "Terminal")
            == "Line 3, column 5, 40 characters, while Terminal was in front. PasteCheck did not change the clipboard."
    )
}

@Test func bodyForImageHasNoLineOrColumn() {
    let findings = [
        finding(kind: .awsAccessKeyID, line: 2, column: 7, length: 20),
        finding(kind: .githubToken, line: 4, column: 1, length: 40),
    ]

    #expect(
        WarningMessage.body(findings: findings, inspectedContent: .image, frontmostAppName: "Preview")
            == "In the copied image (and 1 more match), while Preview was in front. PasteCheck did not change the clipboard."
    )
}

@Test func bodyLeavesOutUnknownAppAndCountsOtherMatches() {
    let findings = [
        finding(kind: .githubToken, line: 1, column: 1, length: 40),
        finding(kind: .jwt, line: 2, column: 1, length: 100),
    ]

    #expect(
        WarningMessage.body(findings: findings, inspectedContent: .text, frontmostAppName: nil)
            == "Line 1, column 1, 40 characters (and 1 more match). PasteCheck did not change the clipboard."
    )
}
