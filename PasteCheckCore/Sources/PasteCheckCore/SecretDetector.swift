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

/// 機密情報の検出 1 件。
public struct Finding: Equatable, Sendable {
    public let kind: String
    public let range: Range<String.Index>

    public init(kind: String, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
}
