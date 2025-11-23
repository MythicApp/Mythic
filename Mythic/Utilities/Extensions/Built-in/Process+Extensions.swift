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
    /// Don't use this for larger outputs — instead use `execute` (async) or `stream` to avoid potential pipe back-pressure.
    static func execute(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) throws -> CommandResult {
        let process = Process()

        process.executableURL = executableURL
        process.arguments = arguments

        if let environment { // if there are unseen env vars, don't remove them
            process.environment = environment
        }
        process.currentDirectoryURL = currentDirectoryURL

        let stderr: Pipe = .init(); process.standardError = stderr
        let stdout: Pipe = .init(); process.standardOutput = stdout

        let log: Logger = .custom(category: "Process.execute@\(executableURL)")

        try process.run()

        let stdoutData = try stdout.fileHandleForReading.readToEnd()
        let stderrData = try stderr.fileHandleForReading.readToEnd()

        process.waitUntilExit()

        // swiftlint:disable optional_data_string_conversion
        let stdoutOutput = String(decoding: stdoutData ?? .init(), as: UTF8.self)
        let stderrOutput = String(decoding: stderrData ?? .init(), as: UTF8.self)
        // swiftlint:enable optional_data_string_conversion

        return .init(standardOutput: stdoutOutput,
                     standardError: stderrOutput,
                     exitCode: process.terminationStatus)
    }

    // allow the compiler to automatically choose execute overload depending on async/sync context
    /// Asynchronously executes a process, and concurrently collects stdout and stderr.
    static func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> CommandResult {
        let process: Process = .init()

        process.executableURL = executableURL
        process.arguments = arguments

        if let environment { // if there are unseen env vars, don't remove them
            process.environment = environment
        }
        process.currentDirectoryURL = currentDirectoryURL

        let stderr: Pipe = .init(); process.standardError = stderr
        let stdout: Pipe = .init(); process.standardOutput = stdout

        let log: Logger = .custom(category: "Process.execute(async)@\(executableURL)")

        try process.run()

        // accumulate piped data asynchronously
        let stdoutTask = Task.detached(priority: .utility) { () -> String in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text = String(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                log.debug("[stdout] \(text, privacy: .public)")
            }
            return text
        }

        let stderrTask = Task.detached(priority: .utility) { () -> String in
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text = String(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                log.debug("[stderr] \(text, privacy: .public)")
            }
            return text
        }

        // wait for termination w/o blocking, concurrency genius!!!!!
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        return .init(standardOutput: await stdoutTask.value,
                     standardError: await stderrTask.value,
                     exitCode: process.terminationStatus)
    }

    static func executeAsync(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> CommandResult {
        try await execute(executableURL: executableURL,
                          arguments: arguments,
                          environment: environment,
                          currentDirectoryURL: currentDirectoryURL)
    }


    /// Starts a process and returns an ``AsyncThrowingStream`` of incremental ``OutputChunk``s.
    /// If `onChunk` is provided, its return value (String) will be written to stdin for each chunk.
    static func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        throwsOnChunkError: Bool = true,
        onChunk: (@Sendable (OutputChunk) throws -> String?)? = nil
    ) -> AsyncThrowingStream<OutputChunk, Error> {
        AsyncThrowingStream { continuation in
            let process: Process = .init()

            process.executableURL = executableURL
            process.arguments = arguments

            if let environment { // if there are unseen env vars, don't remove them
                process.environment = environment
            }
            process.currentDirectoryURL = currentDirectoryURL

            let stdin: Pipe = .init(); process.standardInput = stdin
            let stderr: Pipe = .init(); process.standardError = stderr
            let stdout: Pipe = .init(); process.standardOutput = stdout

            let log: Logger = .custom(category: "Process.stream@\(executableURL)")

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
                let text = String(decoding: data, as: UTF8.self)
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
                    if process.isRunning { process.interrupt() } // try sigint
                    try? await Task.sleep(for: .seconds(6))
                    if process.isRunning { process.terminate() } // try sigterm
                    try? await Task.sleep(for: .seconds(2))
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) } // sigkill, BEGONE

                    safeClose()
                }
            }

            process.terminationHandler = { _ in
                safeClose()
                continuation.finish()
            }

            do {
                try process.run()
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
