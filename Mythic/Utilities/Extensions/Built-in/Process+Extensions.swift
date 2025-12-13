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
    /// Verify that a process' termination status is 0, which is conventionally returned upon successful process execution.
    /// - Throws: ``NonZeroTerminationStatusError`` if the termination status is not 0.
    func checkTerminationStatus() throws {
        guard !self.isRunning else {
            Logger.app.error("Attempted to check termination status of running process [\(self.processIdentifier)].")
            return
        }
        
        if self.terminationStatus != 0 {
            throw NonZeroTerminationStatusError(self.terminationStatus)
        }
    }
    
    /// Synchronously executes a process, and immediately attempts to collect complete stdout/stderr.
    /// - Attention: Don't use this for larger outputs — instead use `execute` (async) or `stream` to avoid potential pipe back-pressure.
    /// - Note: If you don't require output, use `.run()` instead.
    func runWrapped() throws -> CommandResult {
        let stderr: Pipe = .init(); self.standardError = stderr
        let stdout: Pipe = .init(); self.standardOutput = stdout
        
        let log: Logger = .custom(category: "Process[\(self.processIdentifier)] (wrapped) @ \(self.executableURL?.pathComponents.suffix(3).joined(separator: "/") ?? .init())")
        
        try self.run()
        
        let stdoutData = try stdout.fileHandleForReading.readToEnd()
        let stderrData = try stderr.fileHandleForReading.readToEnd()
        
        self.waitUntilExit()
        
        // swiftlint:disable optional_data_string_conversion
        let stdoutOutput = String(decoding: stdoutData ?? .init(), as: UTF8.self)
        let stderrOutput = String(decoding: stderrData ?? .init(), as: UTF8.self)
        // swiftlint:enable optional_data_string_conversion
        
        return .init(standardOutput: stdoutOutput,
                     standardError: stderrOutput)
    }
    
    // allow the compiler to automatically choose execute overload depending on async/sync context
    /// Asynchronously executes a process, and concurrently collects stdout and stderr.
    /// - Note: If you don't require output, use `.run()` instead.
    func runWrapped() async throws -> CommandResult {
        let stderr: Pipe = .init(); self.standardError = stderr
        let stdout: Pipe = .init(); self.standardOutput = stdout
        
        let log: Logger = .custom(category: "Process[\(self.processIdentifier)] (wrapped, async) @ \(self.executableURL?.pathComponents.suffix(3).joined(separator: "/") ?? .init())")
        
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
                     standardError: await stderrTask.value)
    }
    
    func runWrappedAsync() async throws -> CommandResult {
        try await runWrapped()
    }
    
    func runStreamed(throwsOnChunkError: Bool = true) -> AsyncThrowingStream<OutputChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.runStreamed(throwsOnChunkError: throwsOnChunkError) { chunk in
                        continuation.yield(chunk)
                        return nil // `AsyncThrowingStream` can't return replies
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Starts a process and issues a `chunkHandler` callback of incremental ``OutputChunk``s,
    /// With support for responding to input by returning a value to the callback.
    func runStreamed(throwsOnChunkError: Bool = true,
                     chunkHandler: (@Sendable (OutputChunk) throws -> String?)? = nil) async throws {
        let stderr: Pipe = .init(); self.standardError = stderr
        let stdout: Pipe = .init(); self.standardOutput = stdout
        let stdin: Pipe = .init(); self.standardInput = stdin
        
        let log = Logger.custom(
            category: "Process[\(self.processIdentifier)] (streamed) @ \(self.executableURL?.pathComponents.suffix(3).joined(separator: "/") ?? "")"
        )
        
        actor StandardInputWriter {
            let handle: FileHandle
            
            init(handle: FileHandle) {
                self.handle = handle
            }
            
            func write(_ string: String) async {
                guard let data = string.data(using: .utf8) else { return }
                handle.write(data)
            }
        }
        let writer: StandardInputWriter = .init(handle: stdin.fileHandleForWriting)
        
        func attachReadabilityStream(to handle: FileHandle, for stream: Process.Stream) async throws {
            for await data in handle.readabilityDataStream {
                guard !Task.isCancelled else { break }
                
                guard let text: String = . init(data: data, encoding: .utf8) else { continue }
                
                for line in text.split(whereSeparator: \.isNewline) {
                    let chunk: OutputChunk = .init(stream: stream, output: String(line))
                    
                    do {
                        if let chunkHandler, let reply = try chunkHandler(chunk) {
                            await writer.write(reply)
                        }
                    } catch {
                        log.error("[\(stream.rawValue)] caller threw an error: \(error)")
                        if throwsOnChunkError { throw error }
                    }
                    
                    log.debug("[\(stream.rawValue)] \(line, privacy: .public)")
                }
            }
        }
        
        @Sendable func closeFileHandlesForReading() {
            try? stderr.fileHandleForReading.close()
            try? stdout.fileHandleForReading.close()
            try? stdin.fileHandleForWriting.close()
        }
        
        self.terminationHandler = { _ in closeFileHandlesForReading() }
        defer { closeFileHandlesForReading() }
        
        try self.run()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(priority: .utility) {
                try await attachReadabilityStream(to: stderr.fileHandleForReading,
                                                  for: .standardError)
            }
            
            group.addTask(priority: .utility) {
                try await attachReadabilityStream(to: stdout.fileHandleForReading,
                                                  for: .standardOutput)
            }
            
            await withCheckedContinuation { continuation in
                self.waitUntilExit()
                continuation.resume()
            }
            
            // cancel the readability tasks since task has exited
            group.cancelAll()
            
            // throw errors collected by the tasks
            try await group.waitForAll()
        }
    }
}

extension Process {
    struct NonZeroTerminationStatusError: LocalizedError {
        init(_ terminationStatus: Int32? = nil) {
            self.terminationStatus = terminationStatus
        }
        
        var terminationStatus: Int32?
        var errorDescription: String? = String(localized: "Process execution was unsuccessful. (Non-zero exit code)")
    }
    
    enum Stream: String, Sendable {
        case standardError = "stderr"
        case standardOutput = "stdout"
    }
    
    struct OutputChunk: Sendable {
        public let stream: Stream
        public let output: String
    }
    
    struct CommandResult: Sendable {
        public let standardOutput: String
        public let standardError: String
    }
}
