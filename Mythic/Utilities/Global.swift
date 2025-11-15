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

var unifiedGames: [LegacyGame] { (LocalGames.library ?? []) + ((try? Legendary.getInstallable()) ?? []) }

final class SafeErrorStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Error?
    
    func set(_ newValue: Error) { lock.withLock { value = newValue } }
    func get() -> Error? { lock.withLock { value } }
}

var appVersion: SemanticVersion? {
    guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
          let appVersion: SemanticVersion = .init("\(shortVersion)+\(bundleVersion)") else {
        return nil
    }
    
    return appVersion
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
