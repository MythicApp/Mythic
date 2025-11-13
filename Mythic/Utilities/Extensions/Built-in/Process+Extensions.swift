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

        let stderr = Pipe(); process.standardError = stderr
        let stdout = Pipe(); process.standardOutput = stdout

        try process.run()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        // swiftlint:disable optional_data_string_conversion
        let stdoutOutput = String(decoding: stdoutData, as: UTF8.self)
        let stderrOutput = String(decoding: stderrData, as: UTF8.self)
        // swiftlint:enable optional_data_string_conversion

        return CommandResult(
            standardOutput: stdoutOutput,
            standardError: stderrOutput,
            exitCode: process.terminationStatus
        )
    }

    /// Asynchronously executes a process, and concurrently collects stdout and stderr.
    static func executeAsync(
        executableURL: URL,
        arguments: [String] = [],
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

        let stderr = Pipe(); process.standardError = stderr
        let stdout = Pipe(); process.standardOutput = stdout

        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "Mythic",
            category: "Process.executeAsync@\(executableURL)"
        )

        try process.run()

        // accumulate piped data asynchronously
        let stdoutTask = Task.detached(priority: .utility) { () -> String in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text = String(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                logger.debug("[stdout] \(text, privacy: .public)")
            }
            return text
        }

        let stderrTask = Task.detached(priority: .utility) { () -> String in
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            // swiftlint:disable:next optional_data_string_conversion
            let text = String(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                logger.debug("[stderr] \(text, privacy: .public)")
            }
            return text
        }

        // wait for termination w/o blocking, concurrency genius!!!!!
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        return CommandResult(
            standardOutput: await stdoutTask.value,
            standardError: await stderrTask.value,
            exitCode: process.terminationStatus
        )
    }

    static func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> CommandResult {
        try await executeAsync(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
    }

    /// Starts a process and returns an ``AsyncThrowingStream`` of incremental ``OutputChunk``s.
    /// If `onChunk` is provided, its return value (String) will be written to stdin for each chunk.
    static func stream(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        onChunk: (@Sendable (OutputChunk) -> String?)? = nil
    ) -> AsyncThrowingStream<OutputChunk, Error> {
        AsyncThrowingStream { continuation in
            let process: Process = .init()

            process.executableURL = executableURL
            process.arguments = arguments

            if let environment { // if there are unseen env vars, don't remove them
                process.environment = environment
            }
            process.currentDirectoryURL = currentDirectoryURL

            let stdin = Pipe(); process.standardInput = stdin
            let stderr = Pipe(); process.standardError = stderr
            let stdout = Pipe(); process.standardOutput = stdout

            let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "Mythic",
                category: "Process.stream@\(executableURL)"
            )

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
                continuation.yield(chunk)
                logger.debug("[stderr] \(text, privacy: .public)")

                if let onChunk, let reply = onChunk(chunk) {
                    Task { await writer.write(reply) }
                }
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                // swiftlint:disable:next optional_data_string_conversion
                let text = String(decoding: data, as: UTF8.self)
                guard !text.isEmpty else { return }

                let chunk = OutputChunk(stream: .standardOutput, output: text)
                continuation.yield(chunk)
                logger.debug("[stdout] \(text, privacy: .public)")

                if let onChunk, let reply = onChunk(chunk) {
                    Task { await writer.write(reply) }
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
                    try? await Task.sleep(for: .seconds(5))
                    if process.isRunning { process.terminate() } // try sigterm
                    try? await Task.sleep(for: .seconds(2))
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) } // sigkill, taking too long smh

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
