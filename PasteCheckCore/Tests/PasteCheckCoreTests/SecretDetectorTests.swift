import Testing
@testable import PasteCheckCore

// Test values follow `.claude/rules/clipboard-content-handling.md`: they are official sample values or obviously fake,
// and each one is split across string literals so commit hooks and GitHub secret scanning do not flag the source.

/// The AWS documentation's sample access key ID.
private let awsSampleKeyID = "AKIA" + "IOSFODNN7EXAMPLE"
/// The header of the jwt.io sample token: `{"alg":"HS256","typ":"JWT"}`.
private let jwtSampleHeader = "eyJhbGciOiJIUzI1NiIs" + "InR5cCI6IkpXVCJ9"
/// A payload of `{"sub":"1234567890"}`.
private let jwtSamplePayload = "eyJzdWIiOiIxMjM0NTY3" + "ODkwIn0"
/// Stripe's documented Visa test card number.
private let stripeTestCardDigits = ["4242", "4242", "4242", "4242"]

private func kinds(text: String) -> [SecretKind] {
    SecretDetector.findings(in: text).map(\.kind)
}

// MARK: - AWS access key ID

@Test func detectsAWSAccessKeyID() {
    let findings = SecretDetector.findings(in: "aws_access_key_id = " + awsSampleKeyID)

    #expect(findings.map(\.kind) == [.awsAccessKeyID])
    #expect(findings.first?.length == 20)
}

@Test func detectsTemporaryAWSAccessKeyIDInJSON() {
    let findings = SecretDetector.findings(in: "{\"AccessKeyId\": \"" + "ASIA" + "IOSFODNN7EXAMPLE\"}")

    #expect(findings.map(\.kind) == [.awsAccessKeyID])
    #expect(findings.first?.length == 20)
}

@Test func ignoresAWSPrefixWithTooFewCharactersOrInsideAWord() {
    #expect(kinds(text: "AKIA" + "IOSFODNN7EXAMPL").isEmpty)
    #expect(kinds(text: "X" + awsSampleKeyID).isEmpty)
}

// MARK: - GitHub token

@Test(arguments: ["ghp_", "gho_", "ghu_", "ghs_", "ghr_"])
func detectsClassicGitHubTokens(prefix: String) {
    #expect(kinds(text: "token: " + prefix + String(repeating: "a1", count: 18)) == [.githubToken])
}

@Test func detectsFineGrainedGitHubToken() {
    let token = "github" + "_pat_" + "11DUMMY0000000000000000" + "_" + String(repeating: "x9", count: 29) + "z"

    #expect(kinds(text: token) == [.githubToken])
}

@Test func ignoresUnknownGitHubPrefixAndShortToken() {
    #expect(kinds(text: "ghx_" + String(repeating: "a1", count: 18)).isEmpty)
    #expect(kinds(text: "ghp_" + "short1234").isEmpty)
}

// MARK: - OpenAI API key

@Test func detectsOpenAIKey() {
    #expect(kinds(text: "sk-" + "dummyValue1234567890abcd") == [.openAIKey])
}

@Test func detectsOpenAIProjectKey() {
    #expect(kinds(text: "key: sk-" + "proj-" + "dummyValue1234567890abcd") == [.openAIKey])
}

@Test func ignoresShortOrLettersOnlyOpenAIPrefix() {
    #expect(kinds(text: "sk-" + "dummy123").isEmpty)
    #expect(kinds(text: "pip install sk-" + "learn-is-a-python-library").isEmpty)
}

// MARK: - Slack token

@Test(arguments: ["xoxa-", "xoxb-", "xoxp-", "xoxr-", "xoxs-"])
func detectsSlackTokens(prefix: String) {
    #expect(kinds(text: prefix + "0000000000-dummyvalue") == [.slackToken])
}

@Test func ignoresUnknownSlackPrefix() {
    #expect(kinds(text: "xoxz-" + "0000000000-dummyvalue").isEmpty)
}

// MARK: - JWT

@Test func detectsJWTWhoseHeaderHasAlg() {
    let findings = SecretDetector.findings(in: "Bearer " + jwtSampleHeader + "." + jwtSamplePayload + ".dummysignature")

    #expect(findings.map(\.kind) == [.jwt])
    #expect(findings.first?.column == 8)
}

@Test func detectsJWTWhoseHeaderHasWhitespace() {
    // `{ "alg":"HS256"}` encodes to `eyAi...`, not `eyJ...`.
    #expect(kinds(text: "Bearer " + "eyAiYWxnIjoiSFMyNTYifQ" + "." + jwtSamplePayload + ".dummysignature") == [.jwt])
}

@Test func detectsJWTFollowedBySentencePeriod() {
    #expect(kinds(text: "The token is " + jwtSampleHeader + "." + jwtSamplePayload + ".dummysignature.") == [.jwt])
}

@Test func ignoresEyJTextWhoseHeaderHasNoAlg() {
    // `{"foo":"bar"}` decodes to JSON but is not a JOSE header.
    #expect(kinds(text: "eyJmb28iOiJiYXIifQ" + "." + jwtSamplePayload + ".dummysignature").isEmpty)
}

// MARK: - PEM private key

@Test func detectsPEMPrivateKeyBlockIncludingEndLine() {
    let block = "-----BEGIN " + "RSA PRIVATE KEY-----\nplaceholder\n-----END " + "RSA PRIVATE KEY-----"

    let findings = SecretDetector.findings(in: "before\n" + block + "\nafter")

    #expect(findings.map(\.kind) == [.pemPrivateKey])
    #expect(findings.first?.line == 2)
    #expect(findings.first?.length == block.count)
}

@Test func detectsPEMPrivateKeyHeaderAlone() {
    #expect(kinds(text: "-----BEGIN " + "PRIVATE KEY-----") == [.pemPrivateKey])
}

@Test func reportsEachPEMHeaderWithoutEndLineSeparately() {
    let header = "-----BEGIN " + "PRIVATE KEY-----"
    let block = "-----BEGIN " + "EC PRIVATE KEY-----\nplaceholder\n-----END " + "EC PRIVATE KEY-----"
    let text = Array(repeating: header, count: 300).joined(separator: "\n") + "\n" + block

    let findings = SecretDetector.findings(in: text)

    #expect(findings.count == 301)
    #expect(findings.dropLast().allSatisfy { $0.length == header.count })
    #expect(findings.last?.length == block.count)
}

@Test func ignoresPublicKeyAndCertificate() {
    #expect(kinds(text: "-----BEGIN " + "PUBLIC KEY-----").isEmpty)
    #expect(kinds(text: "-----BEGIN " + "CERTIFICATE-----").isEmpty)
}

// MARK: - Credit card number

@Test(arguments: [" ", "-", ""])
func detectsCardNumberThatPassesLuhn(separator: String) {
    #expect(kinds(text: "card: " + stripeTestCardDigits.joined(separator: separator)) == [.creditCardNumber])
}

@Test func detectsCardNumberFollowedByExpiry() {
    let findings = SecretDetector.findings(in: "card: " + stripeTestCardDigits.joined(separator: " ") + " 12/30")

    #expect(findings.map(\.kind) == [.creditCardNumber])
    #expect(findings.first?.length == 19)
}

@Test func detectsCardNumberAfterAnotherNumberGroup() {
    let findings = SecretDetector.findings(in: "23 " + stripeTestCardDigits.joined())

    #expect(findings.map(\.kind) == [.creditCardNumber])
    #expect(findings.first?.column == 4)
    #expect(findings.first?.length == 16)
}

@Test func ignoresCardNumberThatFailsLuhn() {
    #expect(kinds(text: "4242 4242 " + "4242 4241").isEmpty)
}

@Test func ignoresMillisecondTimestamp() {
    // 13 digits like a card number, but starts with 1, which no major card brand issues from.
    #expect(kinds(text: "ts=" + "1760000000000").isEmpty)
}

// MARK: - .env style KEY=value

@Test func detectsEnvAssignmentAndPointsAtTheValue() {
    let findings = SecretDetector.findings(in: "API" + "_TOKEN=" + "dummyValue1234567890abc")

    #expect(findings.map(\.kind) == [.envAssignment])
    #expect(findings.first?.column == 11)
    #expect(findings.first?.length == 23)
}

@Test func detectsCommentedAndExportedEnvAssignments() {
    #expect(kinds(text: "# API" + "_TOKEN=" + "dummyValue1234567890abc") == [.envAssignment])
    #expect(kinds(text: "export API" + "_TOKEN=\"" + "dummyValue1234567890abc\"") == [.envAssignment])
}

@Test func detectsEnvAssignmentWithTrailingComment() {
    let findings = SecretDetector.findings(in: "API" + "_TOKEN=" + "dummyValue1234567890abc # production")

    #expect(findings.map(\.kind) == [.envAssignment])
    #expect(findings.first?.column == 11)
    #expect(findings.first?.length == 23)
}

@Test func detectsQuotedEnvValueContainingHash() {
    let findings = SecretDetector.findings(in: "API" + "_TOKEN=\"" + "dummyValue1234567890#abc\"")

    #expect(findings.map(\.kind) == [.envAssignment])
    #expect(findings.first?.column == 12)
    #expect(findings.first?.length == 24)
}

@Test func ignoresURLValueButDetectsURLWithCredentials() {
    #expect(kinds(text: "NEXT_PUBLIC_API_URL=https://api.example.com/v2").isEmpty)
    #expect(kinds(text: "DATABASE_URL=postgres://dummy:" + "dummyPassword123@db.example.com/app") == [.envAssignment])
}

@Test func ignoresPathLowercaseKeyAndShortValue() {
    #expect(kinds(text: "PATH=/usr/local/bin:/usr/bin:/bin:/sbin").isEmpty)
    #expect(kinds(text: "api_token=" + "dummyValue1234567890abc").isEmpty)
    #expect(kinds(text: "API_TOKEN=" + "dummy123").isEmpty)
}

// MARK: - Ordering and position

@Test func sortsFindingsOfSeveralKindsByPosition() {
    let text = "-----BEGIN " + "PRIVATE KEY-----\n" + "ghp_" + String(repeating: "a1", count: 18) + "\n" + awsSampleKeyID

    #expect(kinds(text: text) == [.pemPrivateKey, .githubToken, .awsAccessKeyID])
}

@Test func reportsBothKindsAtTheSamePositionInDeclarationOrder() {
    let text = "OPENAI_API_KEY=" + "sk-" + "proj-" + "dummyValue1234567890abcd"

    #expect(kinds(text: text) == [.openAIKey, .envAssignment])
}

@Test func reportsLineAndColumnOfEveryMatchInManyLines() {
    let text = (1...200).map { _ in "token " + awsSampleKeyID }.joined(separator: "\n")

    let findings = SecretDetector.findings(in: text)

    #expect(findings.map(\.line) == Array(1...200))
    #expect(findings.allSatisfy { $0.column == 7 })
}

@Test func reportsColumnOfEveryMatchInOneLongLine() {
    let text = (1...200).map { _ in "\"" + awsSampleKeyID + "\"" }.joined(separator: ",")

    let findings = SecretDetector.findings(in: text)

    #expect(findings.count == 200)
    #expect(findings.allSatisfy { $0.line == 1 })
    #expect(findings.map(\.column) == (0..<200).map { $0 * 23 + 2 })
}

@Test func countsCRLFAsOneLineBreak() {
    let findings = SecretDetector.findings(in: "first line\r\nsecond " + awsSampleKeyID)

    #expect(findings.first?.line == 2)
    #expect(findings.first?.column == 8)
}

@Test func findingDescriptionHasNoMatchedText() {
    let findings = SecretDetector.findings(in: awsSampleKeyID)

    #expect(findings.first?.description == "awsAccessKeyID at line 1, column 1, 20 characters")
    #expect(findings.first?.debugDescription.contains("IOSFODNN") == false)
}

@Test func findsNothingInEmptyText() {
    #expect(SecretDetector.findings(in: "").isEmpty)
}
