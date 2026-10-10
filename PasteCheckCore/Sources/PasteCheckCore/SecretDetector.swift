import Foundation

/// クリップボードの文字列から機密情報を検出する。
public enum SecretDetector {
    /// `text` に含まれる機密情報の検出結果を、出現順に返す。
    public static func findings(in text: String) -> [Finding] {
        text.matches(of: /-----BEGIN [A-Z ]*PRIVATE KEY-----/).map { match in
            Finding(kind: "private-key", range: match.range)
        }
    }
}

/// 機密情報の検出 1 件。警告に出してよいのは `kind` と `range` から導く位置情報だけで、
/// 一致した文字列そのものは持たない (`.claude/rules/clipboard-content-handling.md`)。
public struct Finding: Equatable, Sendable {
    /// 検出の種類。値は `SecretDetector` が定義する識別子 (例: `private-key`) で、検出ルールを足す時に増やす。
    public let kind: String
    /// 検査した文字列の中で一致した範囲。
    public let range: Range<String.Index>

    public init(kind: String, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
}
