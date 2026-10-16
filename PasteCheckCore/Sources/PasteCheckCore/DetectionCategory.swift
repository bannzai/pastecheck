import Foundation

/// A checkbox under "Detect" in the menu, which turns a group of `SecretKind`s on or off together. The four token formats
/// share one row because a user turns off "API keys" after false positives, not one service's prefix
/// (the rows of `documents/design/mock-2026-10-11/Main.dc.html`).
public enum DetectionCategory: String, CaseIterable, Sendable {
    case apiKeysAndTokens
    case privateKeys
    case jwt
    case creditCardNumbers
    case envAssignments

    /// The checkbox label in the menu.
    public var title: String {
        switch self {
        case .apiKeysAndTokens:
            return "API keys and tokens"
        case .privateKeys:
            return "Private keys (PEM)"
        case .jwt:
            return "JWT"
        case .creditCardNumbers:
            return "Credit card numbers"
        case .envAssignments:
            return ".env style KEY=value"
        }
    }

    /// The `UserDefaults` key that stores this checkbox. Written out instead of derived from the case name, so renaming
    /// a case cannot silently reset a stored checkbox. No dots, because `@AppStorage` observes the key with KVO, where a
    /// dot separates key path components.
    public var defaultsKey: String {
        switch self {
        case .apiKeysAndTokens:
            return "detectsApiKeysAndTokens"
        case .privateKeys:
            return "detectsPrivateKeys"
        case .jwt:
            return "detectsJwt"
        case .creditCardNumbers:
            return "detectsCreditCardNumbers"
        case .envAssignments:
            return "detectsEnvAssignments"
        }
    }

    /// The kinds this checkbox turns on or off.
    public var kinds: Set<SecretKind> {
        Set(SecretKind.allCases.filter { $0.detectionCategory == self })
    }
}

extension SecretKind {
    /// The "Detect" checkbox that turns this kind on or off. A switch, so a new kind cannot ship without a checkbox.
    public var detectionCategory: DetectionCategory {
        switch self {
        case .awsAccessKeyID, .githubToken, .openAIKey, .slackToken:
            return .apiKeysAndTokens
        case .pemPrivateKey:
            return .privateKeys
        case .jwt:
            return .jwt
        case .creditCardNumber:
            return .creditCardNumbers
        case .envAssignment:
            return .envAssignments
        }
    }
}
