//
//  RPCBridge.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/3/24.
//

import Foundation
import OSLog

extension Engine {
    final class RPCBridge {
        private var log: Logger = .init(subsystem: Logger.subsystem, category: "RPCBridgeInterface")

        static var launchAgentInstalled: Bool {
            let agentURL = FileLocations.userLibrary?.appending(path: "LaunchAgents/com.enderice2.rpc-bridge.plist")
            if let agentURL = agentURL {
                return files.fileExists(atPath: agentURL.path(percentEncoded: false))
            }

            return false
        }

        static func windowsServiceInstalled(containerURL: URL) throws -> Bool {
            guard Wine.containerExists(at: containerURL) else { throw Wine.ContainerDoesNotExistError() }
            return files.fileExists(atPath: containerURL.appending(path: "drive_c/windows/bridge.exe").path(percentEncoded: false))
        }

        private static func mapInstallationType(_ type: InstallationType, usingRemove: Bool) -> String {
            switch type {
            case .uninstall:
                return usingRemove ? "remove" : "uninstall"
            case .install:
                return "install"
            }
        }

        static func modifyLaunchAgent(_ type: InstallationType) async throws {
            guard Engine.exists else { throw Engine.NotInstalledError() }
            guard (type == .install && !launchAgentInstalled) || (type == .uninstall && launchAgentInstalled) else {
                throw {
                    switch type {
                    case .install:
                        return RPCBridge.AlreadyInstalledError()
                    case .uninstall:
                        return RPCBridge.AgentNotInstalledError()
                    }
                }()
            }
            guard let version = version, version >= .init(2, 5, 0) else { throw VersionMismatchError() }

            let mappedType = mapInstallationType(type, usingRemove: true)

            return try await withCheckedThrowingContinuation { continuation in
                Task {
                    do {
                        try await Process.executeAsync(
                            executableURL: .init(filePath: "/bin/bash"),
                            arguments: [Engine.directory.appending(path: "rpc-bridge/launchd.sh").path(percentEncoded: false), mappedType],
                            completion: { output in
                                guard output.stderr.isEmpty else {
                                    continuation.resume(throwing: InstallationError(errorDescription: output.stderr))
                                    return
                                }

                                if output.stdout.contains({
                                    switch type {
                                    case .install:
                                        return "LaunchAgent has been installed."
                                    case .uninstall:
                                        return "LaunchAgent has been removed."
                                    }
                                }()) {
                                    continuation.resume(returning: ())
                                } else {
                                    continuation.resume(throwing: InstallationError(errorDescription: output.stdout))
                                }
                            }
                        )

                        if case .install = type {
                            for container in Wine.containerObjects where container.settings.discordRPC {
                                Task(priority: .background) {
                                    try await modifyWindowsService(.install, containerURL: container.url)
                                }
                            }
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        static func modifyWindowsService(_ type: InstallationType, containerURL: URL) async throws {
            var success = false
            let mappedType = mapInstallationType(type, usingRemove: false)

            try await Wine.command(
                arguments: [
                    Engine.directory
                        .appending(path: "rpc-bridge/bridge.exe")
                        .path(percentEncoded: false),
                    "--\(mappedType)"
                ],
                identifier: "\(mappedType)RPCBridge",
                waits: true,
                containerURL: containerURL
            ) { output in
                guard !success else { return }

                if output.stdout.contains({
                    switch type {
                    case .install:
                        return "Service installed successfully"
                    case .uninstall:
                        return "Service removed successfully"
                    }
                }()) {
                    success = true
                }
            }

            guard success else { throw UnableToModifyWindowsService() }
        }
    }
}

extension Engine.RPCBridge {
    enum InstallationType {
        case install
        case uninstall
    }

    struct AlreadyInstalledError: LocalizedError {
        var errorDescription: String? = "Mythic Engine Discord RPC Bridge is already installed."
    }

    struct AgentNotInstalledError: LocalizedError {
        var errorDescription: String? = "Mythic Engine Discord RPC Bridge's launch agent is not installed."
    }

    struct ServiceNotInstalledError: LocalizedError {
        var errorDescription: String? = "Mythic Engine Discord RPC Bridge's windows service is not installed."
    }

    struct UnableToModifyWindowsService: LocalizedError {
        var errorDescription: String? = "Unable to modify the Mythic Engine Discord RPC Bridge service."
    }

    /// Installation error with a message
    struct InstallationError: LocalizedError {
        var errorDescription: String? = "Unable to install Mythic Engine Discord RPC Bridge."

        init(errorDescription: String) {
            self.errorDescription = errorDescription
        }
    }
}
