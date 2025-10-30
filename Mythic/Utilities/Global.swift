//
//  Global.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import UserNotifications
import SwordRPC
import SemanticVersion

// MARK: - Global Constants
/// A simpler alias of `FileManager.default`.
nonisolated(unsafe) let files: FileManager = .default

/// A simpler alias of `UserDefaults.standard`.
nonisolated(unsafe) let defaults: UserDefaults = .standard

/// A simpler alias of `NSWorkspace.shared`.
nonisolated(unsafe) let workspace: NSWorkspace = .shared

/// A simpler alias of `NSApp[lication].shared`.
@MainActor let sharedApp: NSApplication = .shared

nonisolated(unsafe) let notifications: UNUserNotificationCenter = .current()

let mainLock: NSRecursiveLock = .init()

nonisolated(unsafe) let discordRPC: SwordRPC = .init(appId: "1191343317749870712") // Mythic's discord application ID

var unifiedGames: [Game] { (LocalGames.library ?? []) + ((try? Legendary.getInstallable()) ?? []) }

struct UnknownError: LocalizedError {
    var errorDescription: String? = "An unknown error occurred."
}

var appVersion: SemanticVersion? {
    guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
          let appVersion: SemanticVersion = .init("\(shortVersion)+\(bundleVersion)") else {
        return nil
    }

    return appVersion
}

// MARK: - Functions
// MARK: App Install Checker
/**
 Checks if an app with the given bundle identifier is installed on the system.
 
 - Parameter bundleIdentifier: The bundle identifier of the app.
 - Returns: `true` if the app is installed; otherwise, `false`.
 */
func isAppInstalled(bundleIdentifier: String) -> Bool {
    let process: Process = .init()
    process.launchPath = "/usr/bin/env"
    process.arguments = [
        "bash", "-c",
        "mdfind \"kMDItemCFBundleIdentifier == '\(bundleIdentifier)'\""
    ]
    
    let stdout: Pipe = .init()
    process.standardOutput = stdout
    process.launch()
    
    let data: Data = stdout.fileHandleForReading.readDataToEndOfFile()
    let output: String = .init(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    
    return !output.isEmpty
}

@MainActor
protocol StagedFlow {
    associatedtype Stage: CaseIterable & Equatable

    var stages: [Stage] { get }
    var currentStage: Stage { get set }

    /**
     Steps stage by delta value.
     - Parameters:
     - by: The integer to step the current stage by.
     */
    func stepStage(by delta: Int)
}

struct ActionButton: View {
    @Binding var operating: Bool
    @Binding var successful: Bool?
    let action: () async -> Void
    let label: () -> Label<Text, Image>
    let autoReset: Bool = true

    var body: some View {
        HStack {
            Button {
                Task {
                    withAnimation {
                        operating = true
                        successful = nil
                    }

                    await action()

                    withAnimation {
                        operating = false
                    }
                }
            } label: {
                label()
            }
            .disabled(operating)

            if operating {
                ProgressView()
                    .controlSize(.small)
            } else if let isSuccessful = successful {
                Image(systemName: isSuccessful ? "checkmark" : "xmark")
                    .task {
                        if autoReset {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    successful = nil
                                }
                            }
                        }
                    }
            }
        }
    }
}
