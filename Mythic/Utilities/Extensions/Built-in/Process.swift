//
//  Process.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

extension Process {
    // TODO: FIXME: make redundant ASAP, refactors can be found in my stash, 84505d2
    final class CommandOutput {
        var stdout: String = .init()
        var stderr: String = .init()
    }
}

extension Process {
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

        let stdoutOutput = String(decoding: stdoutData, as: UTF8.self)
        let stderrOutput = String(decoding: stderrData, as: UTF8.self)

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
            let text = String(decoding: data, as: UTF8.self)
            if !text.isEmpty {
                logger.debug("[stdout] \(text, privacy: .public)")
            }
            return text
        }

        let stderrTask = Task.detached(priority: .utility) { () -> String in
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
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
                if process.isRunning {
                    process.terminate()
                }
                safeClose()
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
