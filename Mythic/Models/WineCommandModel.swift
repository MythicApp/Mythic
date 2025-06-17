//
//  WineCommandModel.swift
//  Mythic
//

import Foundation

public enum WineCommandModel {
    /// The logger.
    private static let logger = AppLoggerModel(category: WineCommandModel.self)

    /// Run a wine command.
    /// - Parameters:
    ///  - package: The wine package.
    ///  - arguments: The arguments.
    ///  - enviornment: Environment variables.
    ///  - workingDirectory: The working directory.
    /// - Returns: The process' out put.
    public static func runWineCommand(
        package: EngineInstanceModel.WinePackage,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil
    ) -> Result<ProcessUtility.AsyncProcessEventStream, Error> {
        let process = Process()
        process.executableURL = package.wineBinary
        process.arguments = arguments
        process.environment = environment
        process.qualityOfService = .userInitiated
        process.currentDirectoryURL = workingDirectory

        return ProcessUtility.runProcess(
            process,
            remark: "No remark :P",
            fileHandle: nil
        )
    }

    /// Run a wineserver command.
    /// - Parameters:
    ///   - package: The wine package.
    ///   - arguments: The arguments.
    ///   - enviornment: Environment variables.
    ///   - workingDirectory: The working directory.
    /// - Returns: The process' out put.
    public static func runWineserverCommand(
        package: EngineInstanceModel.WinePackage,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil
    ) -> Result<ProcessUtility.AsyncProcessEventStream, Error> {
        let process = Process()
        process.executableURL = package.wineserverBinary
        process.arguments = arguments
        process.environment = environment
        process.qualityOfService = .userInitiated
        process.currentDirectoryURL = workingDirectory

        return ProcessUtility.runProcess(
            process,
            remark: "No remark :P",
            fileHandle: nil
        )
    }

    /// Create a wine prefix.
    /// - Parameters:
    ///   - package: The wine package.
    ///   - prefixURL: The prefix URL.
    /// - Returns: If the operation was successful.
    public static func createWinePrefix(
        package: EngineInstanceModel.WinePackage,
        prefixURL: URL
    ) async -> Result<Bool, Error> {
        let commandResult = runWineCommand(
            package: package,
            arguments: [
                "wineboot",
                "--init"
            ],
            environment: [
                "WINEPREFIX": prefixURL.path
            ],
            workingDirectory: prefixURL
        )

        let command: ProcessUtility.AsyncProcessEventStream
        switch commandResult {
        case .success(let stream):
            command = stream
        case .failure(let error):
            return .failure(error)
        }

        logger.info("Creating wine prefix: \(prefixURL.absoluteString)")

        // Await termination (AsyncStream)
        for await event in command {
            switch event {
            case .processTerminate(let process):
                // Check if the process terminated successfully
                logger.info(
                    "Wine prefix creation process terminated with exit code: \(process.terminationStatus).")
                if process.terminationStatus == 0 {
                    return .success(true)
                } else {
                    return .success(false)
                }
            default:
                break
            }
        }

        return .success(false)
    }
}
