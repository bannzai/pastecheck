import Testing
@testable import PasteCheckCore

@Test func PEM秘密鍵のヘッダを1件検出する() {
    // 秘密鍵ブロックを検出する commit 前の点検に、テストデータが誤検知されないよう文字列を分けて書く。
    let text = "-----BEGIN " + "RSA PRIVATE KEY-----\nplaceholder"

    let findings = SecretDetector.findings(in: text)

    #expect(findings.count == 1)
    #expect(findings.first?.kind == "private-key")
}

@Test func 空文字では何も検出しない() {
    #expect(SecretDetector.findings(in: "").isEmpty)
}
