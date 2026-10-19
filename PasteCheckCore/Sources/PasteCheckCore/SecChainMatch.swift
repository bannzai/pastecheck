import Foundation

/// The result of asking SecChain (https://github.com/bannzai/SecChain ) which of its stored secrets a copied text holds.
/// SecChain answers with names only, so nothing here carries a value (`documents/PROJECT.md` invariant 1).
public enum SecChainMatchOutcome: Equatable, Sendable {
    /// `secchain match` ran. `labels` are the matched secrets, each a name followed by where it is stored in
    /// parentheses, such as `OPENAI_API_KEY (scope user)`; empty when the text holds no stored value.
    case matched(labels: [String])
    /// The SecChain command-line tool is not where SecChain installs it.
    case notInstalled
    /// The tool was found but no answer came back: its signature did not check out, it could not be started, it failed
    /// (for example when it cannot read the Keychain), it took too long, or it answered with something unreadable.
    /// PasteCheck then warns from its own patterns only (fail open).
    case failed

    /// The matched secrets to warn about; none unless SecChain answered with a match.
    public var matchedLabels: [String] {
        guard case .matched(let labels) = self else {
            return []
        }
        return labels
    }
}

/// Reads the answer of `secchain match`, the subcommand SecChain added for PasteCheck
/// (https://github.com/bannzai/SecChain/pull/92 ). It writes one matched secret per line on standard output and
/// nothing when there is no match, exits 0 either way, and exits 1 with the reason on standard error when the Keychain
/// cannot be read.
public enum SecChainMatch {
    /// The outcome of one run of `secchain match`.
    /// - Parameters:
    ///   - terminationStatus: The exit status, or the signal number when `terminatedBySignal`.
    ///   - terminatedBySignal: Whether the process was killed, for example by PasteCheck's timeout, instead of exiting.
    ///   - standardOutput: Everything the process wrote on standard output.
    public static func outcome(terminationStatus: Int32, terminatedBySignal: Bool, standardOutput: Data) -> SecChainMatchOutcome {
        guard !terminatedBySignal, terminationStatus == 0, let output = String(data: standardOutput, encoding: .utf8) else {
            return .failed
        }
        return .matched(labels: output.split(whereSeparator: \.isNewline).map(String.init))
    }
}
