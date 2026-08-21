//
//  SteamGameInstallationView.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import OSLog

struct SteamGameInstallationView: View {
    @Binding var game: SteamGame
    @Binding var isPresented: Bool

    @State private var isImageEmpty: Bool = true
    @State var isOperating: Bool = false

    @State private var appInfo: ValveDataFormat.AppInfo?
    @State private var isFetchingAppInfo: Bool = false

    private var installURL: URL { Steam.installURL(forAppID: game.appID) }

    /// The platform SteamCMD will actually be told to fetch, from Settings ▸ Services ▸ Steam.
    private var forcedPlatform: Game.Platform {
        Steam.forcedPlatform == .macos ? .macOS : .windows
    }

    private var isPlatformAvailable: Bool {
        guard let appInfo else { return true }  // unknown until looked up; do not block on it
        return Steam.supportedPlatforms(for: appInfo).contains(forcedPlatform)
    }

    var body: some View {
        BaseGameInstallationView(
            game: .init(get: { game as Game },
                        set: { if let castGame = $0 as? SteamGame { game = castGame } }),
            isPresented: $isPresented,
            isImageEmpty: $isImageEmpty,
            type: "Install",
            operating: $isOperating,
            action: {
                _ = try await SteamGameManager.install(steamGame: game, atQualityOfService: .default)
            },
            content: {
                Form {
                    LabeledContent("App ID", value: game.appID)

                    if isFetchingAppInfo {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Checking download size…").foregroundStyle(.secondary)
                        }
                    } else if let downloadSize = appInfo?.downloadSize {
                        LabeledContent("Download",
                                       value: downloadSize.formatted(.byteCount(style: .file)))
                    }

                    LabeledContent("Platform", value: forcedPlatform.description)

                    LabeledContent("Location") {
                        Text(installURL.prettyPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    if !isPlatformAvailable {
                        Label("Steam doesn't offer a \(forcedPlatform.description) build of this title. Change the platform in Settings ▸ Services ▸ Steam.",
                              systemImage: "exclamationmark.triangle")
                        .symbolVariant(.fill)
                    }

                    if forcedPlatform == .windows {
                        // Stated plainly rather than detected: guessing wrong is worse than saying
                        // nothing, and there is no reliable signal for it in the depot metadata.
                        Label("Titles that require the Steam client running won't launch — Mythic Engine can't run it.",
                              systemImage: "info")
                        .symbolVariant(.circle)
                        .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            }
        )
        .navigationTitle("Install \(game.description)")
        .task {
            guard appInfo == nil else { return }
            isFetchingAppInfo = true
            defer { isFetchingAppInfo = false }

            appInfo = Steam.cachedAppInfo(appID: game.appID)
            if appInfo == nil {
                appInfo = try? await Steam.refreshAppInfo(appID: game.appID)
            }
        }
    }
}

#Preview {
    SteamGameInstallationView(
        game: .constant(.init(appID: "1623730", title: "Palworld", installationState: .uninstalled)),
        isPresented: .constant(true)
    )
    .padding()
}
