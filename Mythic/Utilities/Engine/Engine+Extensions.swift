//
//  Engine+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SemanticVersion

extension Engine {
    enum InstallStage {
        case downloading
        case installing
    }

    struct InstallProgress {
        var stage: InstallStage
        var progress: Progress
    }

    struct EngineProperties: Codable {
        let version: SemanticVersion
    }
}

extension Engine {
    struct NotInstalledError: LocalizedError {
        var errorDescription: String? = String(localized: "Mythic Engine is not installed.")
    }

    struct UnableToRetrieveCompatibleReleaseError: LocalizedError {
        var errorDescription: String? = String(localized: "Unable to retrieve a compatible Mythic Engine release for this stream.")
    }
}

import SwiftUI

extension Engine {
    struct NotInstalledView: View {
        @State private var isInstallationViewPresented: Bool = false

        @State private var installationError: Error?
        @State private var installationComplete: Bool = false

        var body: some View {
            VStack {
                if !Engine.isInstalled {
                    ContentUnavailableView(
                        "Mythic Engine is not installed.",
                        systemImage: "arrow.down.circle.badge.xmark.fill",
                        description: .init("""
                    To access containers, Mythic Engine must be installed.
                    """)
                    )
                    Button("Install Mythic Engine", systemImage: "arrow.down.circle.fill") {
                        isInstallationViewPresented = true
                    }
                }
            }
            .sheet(isPresented: $isInstallationViewPresented) {
                EngineInstallationView(
                    isPresented: $isInstallationViewPresented,
                    installationError: $installationError,
                    installationComplete: $installationComplete
                )
                .padding()
            }
        }
    }
}
