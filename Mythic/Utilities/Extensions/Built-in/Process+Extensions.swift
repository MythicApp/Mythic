//
//  Process.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

extension Process {
    /// Synchronously executes a process, and immediately attempts to collect complete stdout/stderr.
    /// - Note: Don't use this for larger outputs — instead use `execute` (async) or `stream` to avoid potential pipe back-pressure.
    /// - Note: If you don't require output, use `.run()` instead.
    func runWrapped() throws -> CommandResult {
        let stderr: Pipe = .init(); self.standardError = stderr
        let stdout: Pipe = .init(); self.standardOutput = stdout

        let log: Logger = .custom(category: "Process.execute@\(self.executableURL?.path ?? "Unknown\(UUID().uuidString)")")

        try self.run()

        let stdoutData = try stdout.fileHandleForReading.readToEnd()
        let stderrData = try stderr.fileHandleForReading.readToEnd()

        self.waitUntilExit()

        // swiftlint:disable optional_data_string_conversion
        let stdoutOutput = String(decoding: stdoutData ?? .init(), as: UTF8.self)
        let stderrOutput = String(decoding: stderrData ?? .init(), as: UTF8.self)
        // swiftlint:enable optional_data_string_conversion

        return .init(standardOutput: stdoutOutput,
                     standardError: stderrOutput,
                     exitCode: self.terminationStatus)
    }

    // allow the compiler to automatically choose execute overload depending on async/sync context
    /// Asynchronously executes a process, and concurrently collects stdout and stderr.
    /// - Note: If you don't require output, use `.run()` instead.
    func runWrapped() async throws -> CommandResult {
        let stderr: Pipe = .init(); self.standardError = stderr
        let stdout: Pipe = .init(); self.standardOutput = stdout

        let log: Logger = .custom(category: "Process.execute(async)@\(self.executableURL?.path ?? "Unknown\(UUID().uuidString)")")

        try self.run()

        // accumulate piped data asynchronously
        let stdoutTask = Task.detached(priority: .utility) { () -> String in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text: String = .init(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                log.debug("[stdout] \(text, privacy: .public)")
            }
            return text
        }

        let stderrTask = Task.detached(priority: .utility) { () -> String in
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text: String = .init(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                log.debug("[stderr] \(text, privacy: .public)")
            }
            return text
        }

        // wait for termination w/o blocking, concurrency genius!!!!!
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.terminationHandler = { _ in
                continuation.resume()
            }
        }

        return .init(standardOutput: await stdoutTask.value,
                     standardError: await stderrTask.value,
                     exitCode: self.terminationStatus)
    }

    func runWrappedAsync() async throws -> CommandResult {
        try await runWrapped()
    }
    
    /// Starts a process and returns an ``AsyncThrowingStream`` of incremental ``OutputChunk``s.
    /// If `onChunk` is provided, its return value (String) will be written to stdin for each chunk.
    func runStreamed(
        throwsOnChunkError: Bool = true,
        onChunk: (@Sendable (OutputChunk) throws -> String?)? = nil
    ) -> AsyncThrowingStream<OutputChunk, Error> {
        AsyncThrowingStream { continuation in
            let stdin: Pipe = .init(); self.standardInput = stdin
            let stderr: Pipe = .init(); self.standardError = stderr
            let stdout: Pipe = .init(); self.standardOutput = stdout

            let log: Logger = .custom(category: "Process.runStreamed@\(self.executableURL?.path ?? "Unknown\(UUID().uuidString)")")

            // safety first!! (keep swift 6 happy)
            actor StdinWriter {
                private let handle: FileHandle
                init(handle: FileHandle) { self.handle = handle }
                func write(_ string: String) {
                    if let data = string.data(using: .utf8) {
                        handle.write(data)
                    }
                }
            }
            let writer = StdinWriter(handle: stdin.fileHandleForWriting)

            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                // swiftlint:disable:next optional_data_string_conversion
                let text: String = .init(decoding: data, as: UTF8.self)
                guard !text.isEmpty else { return }

                let chunk = OutputChunk(stream: .standardError, output: text)

                do {
                    if let onChunk, let reply = try onChunk(chunk) {
                        Task { await writer.write(reply) }
                    }
                    continuation.yield(chunk)
                    log.debug("[stderr] \(text, privacy: .public)")
                } catch {
                    log.warning("[stderr] caller threw an error while processing stream output: \(error)")
                    if throwsOnChunkError {
                        continuation.finish(throwing: error)
                    }
                }
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                // swiftlint:disable:next optional_data_string_conversion
                let text: String = .init(decoding: data, as: UTF8.self)
                guard !text.isEmpty else { return }

                let chunk: OutputChunk = .init(stream: .standardOutput, output: text)
                do {
                    if let onChunk, let reply = try onChunk(chunk) {
                        Task { await writer.write(reply) }
                    }
                    continuation.yield(chunk)
                    log.debug("[stdout] \(text, privacy: .public)")
                } catch {
                    log.warning("[stdout] caller threw an error while processing stream output: \(error)")
                    if throwsOnChunkError {
                        continuation.finish(throwing: error)
                    }
                }
            }

            @Sendable func safeClose() {
                stderr.fileHandleForReading.readabilityHandler = nil
                stdout.fileHandleForReading.readabilityHandler = nil
                try? stderr.fileHandleForReading.close()
                try? stdout.fileHandleForReading.close()
                try? stdin.fileHandleForWriting.close()
            }

            // cancel/finish handling: if the consumer cancels, terminate the child gracefully.
            continuation.onTermination = { @Sendable _ in
                Task.detached {
                    if self.isRunning { self.interrupt() } // try sigint
                    try? await Task.sleep(for: .seconds(6))
                    if self.isRunning { self.terminate() } // try sigterm
                    try? await Task.sleep(for: .seconds(2))
                    if self.isRunning { kill(self.processIdentifier, SIGKILL) } // sigkill, BEGONE

                    safeClose()
                }
            }

            self.terminationHandler = { _ in
                safeClose()
                continuation.finish()
            }

            do {
                try self.run()
            } catch {
                safeClose()
                continuation.finish(throwing: error)
            }
        }
    }
}

extension Process {
    struct NonZeroExitCodeError: LocalizedError {
        init(exitCode: Int32? = nil) {
            self.exitCode = exitCode
        }

        var exitCode: Int32?
        var errorDescription: String? = String(localized: "Process execution was unsuccessful. (Non-zero exit code)")
    }

    enum Stream: Sendable {
        case standardError
        case standardOutput
    }

    struct OutputChunk: Sendable {
        public let stream: Stream
        public let output: String
    }

    struct CommandResult: Sendable {
        public let standardOutput: String
        public let standardError: String
        public let exitCode: Int32
    }
}
