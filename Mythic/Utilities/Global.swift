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

nonisolated(unsafe) let discordRPC: SwordRPC = .init(appId: "1191343317749870712")

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
