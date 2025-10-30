//
//  SparkleUpdateControllerModel.swift
//  Mythic
//
//  Created by Josh.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

public class AppSettingsModel: ObservableObject {
    @MainActor public static let shared: AppSettingsModel = .init()

    /// Private initializer
    private init() {}

    /// Settings
    public struct Settings: Hashable {
        /// If the user has completed onboarding.
        public var inOnboarding: Bool = true
    
        /// Auto update settings.
        public enum AutoUpdateAction: String, Sendable, Codable, Hashable {
            case off
            case check
            case install
        }
        public var sparkleUpdateAction: AutoUpdateAction = .install
    }

    /// The settings
    @Published var settings: Settings = .init()
}
