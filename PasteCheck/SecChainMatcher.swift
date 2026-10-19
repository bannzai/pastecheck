import Foundation
import PasteCheckCore
import Security

/// Asks SecChain (https://github.com/bannzai/SecChain ) which of its stored secrets a copied text holds, by running its
/// `secchain match` command (https://github.com/bannzai/SecChain/pull/92 ).
///
/// This is the one place where clipboard text leaves PasteCheck (`documents/PROJECT.md` invariant 1): the text goes to
/// the genuine SecChain tool on this Mac, on standard input (arguments are visible to every process through `ps`), and
/// only the names of matched secrets come back. The stored values are read by SecChain alone and never reach
/// PasteCheck (SecChain's design decision 8 in https://github.com/bannzai/SecChain/blob/main/documents/PROJECT.md ).
/// Neither the text nor anything the tool writes is logged or kept.
enum SecChainMatcher {
    /// The bundle SecChain embeds its command-line tool in (`SecChain.app/Contents/Helpers/secchain.app`, SecChain's
    /// `documents/PROJECT.md`), under `/Applications`, where SecChain's `make macos` installs SecChain.app. An app moved
    /// elsewhere reads as not installed.
    static let toolBundleURL = URL(fileURLWithPath: "/Applications/SecChain.app/Contents/Helpers/secchain.app")
    /// The tool's executable inside `toolBundleURL`, named by `CFBundleExecutable` in SecChain's
    /// `SecChainCLISupport/Info.plist`.
    static let toolExecutableURL = toolBundleURL.appending(path: "Contents/MacOS/secchain")
    /// What the tool's signature must satisfy before it is handed any text: signed through Apple by SecChain's team
    /// (`DEVELOPMENT_TEAM` of `SecChain.xcodeproj`) with the tool's bundle identifier (`CFBundleIdentifier` of
    /// `SecChainCLISupport/Info.plist`). Holds for both SecChain's Developer ID releases and its development builds.
    static let toolCodeRequirement =
        #"anchor apple generic and identifier "com.bannzai.SecChain.cli" and certificate leaf[subject.OU] = "TQPN82UBBY""#
    /// How long one match may take before the tool is stopped and the warning goes out from PasteCheck's own patterns.
    /// The warning waits for the match so one copy gives one warning, and a warning that arrives after the user pasted
    /// is too late; a copy-switch-paste takes a few seconds. The tool reads only `standard` secrets, which need no
    /// authentication prompt, so a healthy run is far shorter.
    static let timeout: Duration = .seconds(5)

    /// Whether the SecChain tool is installed. Says nothing about whether it is genuine or works.
    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: toolExecutableURL.path)
    }

    /// Runs `secchain match` on `text` off the main actor. Cancelling the calling task stops the tool, so a copy that
    /// replaced the text does not leave a process behind.
    nonisolated static func match(text: String) async -> SecChainMatchOutcome {
        guard isInstalled else {
            return .notInstalled
        }
        // Checked on every match, because SecChain can be replaced while PasteCheck runs, so that a replaced tool is
        // not even started. The bundle can still be swapped between this check and the launch (an app installed by
        // the user is writable by the user's processes), so `ToolRun` checks the started process too before it hands
        // over any text.
        guard hasGenuineSignature() else {
            return .failed
        }
        let run = ToolRun()
        let timeoutTask = Task.detached {
            // Cancelled when the run finished in time, and then there is nothing to stop.
            guard (try? await Task.sleep(for: timeout)) != nil else {
                return
            }
            run.stop()
        }
        defer {
            timeoutTask.cancel()
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // On a Dispatch queue rather than a task, because the run blocks its thread until the tool exits, and
                // the Swift concurrency pool has only as many threads as there are cores.
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: run.perform(text: text))
                }
            }
        } onCancel: {
            run.stop()
        }
    }

    /// Whether the tool bundle on disk satisfies `toolCodeRequirement`.
    nonisolated private static func hasGenuineSignature() -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(toolBundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode,
              let requirement = codeRequirement() else {
            return false
        }
        return SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess
    }

    /// Whether the running process `processIdentifier` satisfies `toolCodeRequirement`. Checks the code the process
    /// actually runs, so a tool swapped in after `hasGenuineSignature()` fails here. Whether this check is allowed from
    /// inside the App Sandbox is part of the real-Mac check (https://github.com/bannzai/pastecheck/issues/2 ); if it is
    /// not, every match fails and the menu says "Could not match, patterns only", and no text has been handed over.
    nonisolated static func isGenuineRunningTool(processIdentifier: Int32) -> Bool {
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(
            nil,
            [kSecGuestAttributePid as String: processIdentifier] as CFDictionary,
            [],
            &code
        ) == errSecSuccess,
              let code,
              let requirement = codeRequirement() else {
            return false
        }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    /// `toolCodeRequirement` compiled, or `nil` if it does not compile, which fails both checks.
    nonisolated private static func codeRequirement() -> SecRequirement? {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(toolCodeRequirement as CFString, [], &requirement) == errSecSuccess else {
            return nil
        }
        return requirement
    }
}

/// One run of the SecChain tool, shared between the task that performs it and the timeout and cancellation that stop
/// it. `@unchecked Sendable` because `Process` is not marked `Sendable`; every access to it goes through `lock`.
private final class ToolRun: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    /// Set by `stop()`, so a stop that comes before the launch keeps the tool from starting.
    private var isStopped = false

    /// Starts the tool, writes `text` to its standard input, and waits for it to exit. Blocks the calling thread.
    func perform(text: String) -> SecChainMatchOutcome {
        let input = Pipe()
        let output = Pipe()
        lock.lock()
        process.executableURL = SecChainMatcher.toolExecutableURL
        process.arguments = ["match"]
        process.standardInput = input
        process.standardOutput = output
        // Standard error explains a failure in words that are not needed here and is not shown or kept.
        process.standardError = FileHandle.nullDevice
        guard !isStopped, (try? process.run()) != nil else {
            lock.unlock()
            return .failed
        }
        lock.unlock()
        // A child is not reaped before `waitUntilExit()`, so its process identifier cannot belong to another process
        // here. Closing the input lets a tool that ignores the termination see the end of it and exit.
        guard SecChainMatcher.isGenuineRunningTool(processIdentifier: process.processIdentifier) else {
            stop()
            try? input.fileHandleForWriting.close()
            process.waitUntilExit()
            return .failed
        }
        // Written from another thread and closed, so the tool sees the end of its input while this thread drains its
        // output. A tool that exits early closes the pipe, and without `F_SETNOSIGPIPE` writing to it would raise
        // SIGPIPE and terminate PasteCheck.
        let inputHandle = input.fileHandleForWriting
        _ = fcntl(inputHandle.fileDescriptor, F_SETNOSIGPIPE, 1)
        let textData = Data(text.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            try? inputHandle.write(contentsOf: textData)
            try? inputHandle.close()
        }
        let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return SecChainMatch.outcome(
            terminationStatus: process.terminationStatus,
            terminatedBySignal: process.terminationReason == .uncaughtSignal,
            standardOutput: standardOutput
        )
    }

    /// Stops the tool, or keeps it from starting. Idempotent: once stopped, nothing more happens.
    func stop() {
        lock.lock()
        defer {
            lock.unlock()
        }
        isStopped = true
        if process.isRunning {
            process.terminate()
        }
    }
}
