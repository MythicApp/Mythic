//
//  Global.swift
//  Mythic
//
//  Created by zenfty on 11/10/2023.
//

// Copyright © 2023-2026 zenfty

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
