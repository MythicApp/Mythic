//
//  ProcessUtility.swift
//  Mythic
//

import Foundation

public enum ProcessUtility {
    private static let logger = AppLoggerModel(category: ProcessUtility.self)

    public typealias AsyncProcessEventStream = AsyncStream<ProcessEvent>

    /// Events that can happen while a process is running.
    public enum ProcessEvent: Sendable, Hashable {
        case processStart(Process)
        case standardOutput(String)
        case standardError(String)
        case processTerminate(Process)
    }

    /// Enviornment Item.
    public struct EnviornmentItem: Codable, Sendable, Hashable {
        public let key: String
        public let value: String
    }

    /// Information for a process run.
    public struct ProcessUtilityInformation: Codable, Sendable, Hashable {
        public let remark: String?
        public let executionDate: Date
        public let executablePath: String
        public let workingDirectory: String
        public let arguments: [String]
        public let enviornment: [EnviornmentItem]
    }

    /// Information for a process termination.
    public struct ProcessTerminationInformation: Codable, Sendable, Hashable {
        public let exitCode: Int32
        public let terminationDate: Date
    }

    /// Serialize a `ProcessUtilityInformation`.
    /// - Parameter information: The information to serialize.
    /// - Returns: A string.
    private static func encodeProcessUtilityInformation(information: ProcessUtilityInformation)
        -> Data?
    {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        encoder.dateEncodingStrategy = .formatted(formatter)

        do {
            return try encoder.encode(information)
        } catch {
            logger.error("Failed to encode: \(error.localizedDescription)")
            return nil
        }
    }

    /// Serialize a `ProcessTerminationInformation`.
    /// - Parameter information: The information to serialize.
    /// - Returns: A string.
    private static func encodeProcessTerminationInformation(
        information: ProcessTerminationInformation
    )
        -> Data?
    {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        encoder.dateEncodingStrategy = .formatted(formatter)

        do {
            return try encoder.encode(information)
        } catch {
            logger.error("Failed to encode: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fileHandleWriteString(
        _ fileHandle: FileHandle? = nil,
        _ contentString: String
    ) {
        guard let fileHandle else { return }

        guard let data = contentString.data(using: .utf8) else {
            logger.warning("Failed to encode content string as UTF-8.")
            return
        }

        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            logger.warning("Failed to log (string): \(error)")
        }
    }

    private static func fileHandleWriteData(
        _ fileHandle: FileHandle? = nil,
        _ contentData: Data
    ) {
        guard let fileHandle else { return }

        do {
            try fileHandle.write(contentsOf: contentData)
        } catch {
            logger.warning("Failed to log (data): \(error)")
        }
    }

    private static func fileHandleReadString(
        _ fileHandle: FileHandle
    ) -> String? {
        if let data = String(data: fileHandle.availableData, encoding: .utf8) {
            return data.isEmpty ? nil : data
        }
        logger.warning("Failed to read data from file handle.")
        return nil
    }

    /// Create a process stream.
    /// - Parameters:
    ///   - process: The process to set the output on.
    ///   - remark: A comment, maybe about why or what the process does.
    ///   - executablePath: The path to the run executable.
    ///   - workingDirectory: The working directory.
    ///   - arguments: The arguments provided to the process.
    ///   - enviornment: Enviornment varibles
    ///   - fileHandle: The file to write this info to.
    ///
    private static func createProcessEventStream(
        process: Process,
        remark: String? = nil,
        executablePath: URL,
        workingDirectory: URL,
        arguments: [String],
        enviornment: [String: String],
        fileHandle: FileHandle?
    ) -> AsyncStream<ProcessEvent> {
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        let processUtilityInformation = ProcessUtilityInformation(
            remark: remark,
            executionDate: .now,
            executablePath: executablePath.absoluteString,
            workingDirectory: workingDirectory.absoluteString,
            arguments: arguments,
            enviornment: enviornment.enumerated().map {
                EnviornmentItem(key: $0.element.key, value: $0.element.value)
            }
        )
        if let encoded = encodeProcessUtilityInformation(information: processUtilityInformation) {
            fileHandleWriteData(fileHandle, encoded)
        }
        fileHandleWriteString(fileHandle, "\n-----\n")

        return AsyncStream<ProcessEvent> { continuation in
            continuation.onTermination = { termination in
                switch termination {
                case .finished:
                    break
                case .cancelled:
                    guard process.isRunning else { return }
                    process.terminate()
                @unknown default:
                    break
                }
            }

            continuation.yield(.processStart(process))

            standardOutput.fileHandleForReading.readabilityHandler = { pipe in
                guard let output = fileHandleReadString(pipe), output.isEmpty else { return }
                continuation.yield(.standardOutput(output))
                fileHandleWriteString(fileHandle, output)
            }

            standardError.fileHandleForReading.readabilityHandler = { pipe in
                guard let error = fileHandleReadString(pipe), error.isEmpty else { return }
                continuation.yield(.standardError(error))
                fileHandleWriteString(fileHandle, error)
            }

            process.terminationHandler = { process in
                let processTerminationInformation = ProcessTerminationInformation(
                    exitCode: process.terminationStatus,
                    terminationDate: .now
                )

                fileHandleWriteString(fileHandle, "\n-----\n")

                if let encoded = encodeProcessTerminationInformation(
                    information: processTerminationInformation
                ) {
                    fileHandleWriteData(fileHandle, encoded)
                }

                continuation.yield(.processTerminate(process))
                continuation.finish()
            }
        }
    }

    /// Run a process.
    /// - Parameters:
    ///   - process: The process to run.
    ///   - remark: A comment, maybe about why or what the process does.
    ///   - fileHandle: The file to write this info to.
    public static func runProcess(
        _ process: Process,
        remark: String? = nil,
        fileHandle: FileHandle? = nil
    ) -> Result<AsyncStream<ProcessEvent>, Error> {
        let stream = createProcessEventStream(
            process: process,
            remark: remark,
            executablePath: URL(fileURLWithPath: process.launchPath ?? ""),
            workingDirectory: URL(fileURLWithPath: process.currentDirectoryPath),
            arguments: process.arguments ?? [],
            enviornment: ProcessInfo.processInfo.environment,
            fileHandle: fileHandle
        )

        do {
            try process.run()
        } catch {
            return .failure(error)
        }

        return .success(stream)
    }
}
