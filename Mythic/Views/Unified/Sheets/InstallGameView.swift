//
//  InstallGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/3/2024.
//

import SwiftUI
import OSLog

struct InstallViewEvo: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @State var optionalPacks: [String: String] = .init()
    @State var selectedOptionalPacks: Set<String> = .init()
    @State var fetchingOptionalPacks: Bool = true

    @State var installSize: Double?

    @State private var supportedPlatforms: [Game.Platform]?
    @State var platform: Game.Platform = .macOS

    @State private var isInstallationErrorPresented: Bool = false
    @State private var installationError: Error?

    @AppStorage("installBaseURL") private var baseURL: URL = Bundle.appGames!
    @ObservedObject var operation: GameOperation = .shared

    private func fetchOptionalPacks() async {
        withAnimation { fetchingOptionalPacks = true }

        try? await Legendary.command(
            arguments: [
                "install", game.id,
                "--platform", {
                    switch platform {
                    case .macOS: "Mac"
                    case .windows: "Windows"
                    }
                }()
            ],
            identifier: "parseOptionalPacks"
        ) { output in
            if output.stdout.contains("The following optional packs are available") { // hate hardcoding
                Logger.app.debug("Found optional packs")
                output.stdout.enumerateLines { line, _ in
                    Logger.app.debug("Adding optional pack \"\(line)\"")
                    if let match = try? Regex(#"\s*\* (?<identifier>\w+) - (?<name>.+)"#).firstMatch(in: line) {
                        _ = withAnimation {
                            optionalPacks.updateValue(String(match["name"]?.substring ?? .init()), forKey: String(match["identifier"]?.substring ?? .init()))
                        }
                    }
                }
            }

            if output.stderr.contains("Install size:") {
                if let match = try? Regex(#"Install size: (\d+(\.\d+)?) MiB"#).firstMatch(in: output.stderr) {
                    installSize = Double(match[1].substring ?? "") ?? 0.0
                }
            }

            if output.stdout.contains("Do you wish to install") || output.stdout.contains("Additional packs") {
                Legendary.stopCommand(identifier: "parseOptionalPacks", forced: true)
                return
            }
        }

        withAnimation { fetchingOptionalPacks = false }
    }

    var body: some View {
        Text("Install \"\(game.title)\"")
            .font(.title)
            .alert(isPresented: $isInstallationErrorPresented) {
                Alert(
                    title: .init("Unable to proceed with installation."),
                    message: .init(installationError?.localizedDescription ?? "Unknown error."),
                    dismissButton: .default(.init("OK")) {
                        isPresented = false
                    }
                )
            }
            .onDisappear {
                Legendary.stopCommand(identifier: "parseOptionalPacks")
            }

        if operation.current != nil {
            Text("Cannot fetch selected downloads while other items are downloading.")
                .font(.footnote)
                .foregroundStyle(.placeholder)
        }

        if !optionalPacks.isEmpty {
            Text("(Supports selective downloads)")
                .font(.footnote)
                .foregroundStyle(.placeholder)

            Form {
                ForEach(optionalPacks.sorted(by: { $0.key < $1.key }), id: \.key) { tag, name in
                    HStack {
                        Text(name)
                        Text(tag)
                            .font(.footnote)
                            .foregroundStyle(.placeholder)

                        Spacer()

                        Toggle(
                            isOn: Binding(
                                get: { return selectedOptionalPacks.contains(tag) },
                                set: { enabled in
                                    if enabled {
                                        selectedOptionalPacks.insert(tag)
                                    } else {
                                        selectedOptionalPacks.remove(tag)
                                    }
                                }
                            )
                        ) {  }
                    }
                }
            }
            .formStyle(.grouped)
        }

        Form {
            HStack {
                VStack(alignment: .leading) {
                    Text("Where do you want the game's base path to be located?")

                    Text(baseURL.prettyPath())
                        .foregroundStyle(.placeholder)
                }

                Spacer()

                if !FileLocations.isWritableFolder(url: baseURL) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .help("Folder is not writable.")
                }

                // TODO: unify
                Button("Browse...") {
                    let openPanel = NSOpenPanel()
                    openPanel.canChooseDirectories = true
                    openPanel.canChooseFiles = false
                    openPanel.canCreateDirectories = true
                    openPanel.allowsMultipleSelection = false

                    if openPanel.runModal() == .OK {
                        baseURL = openPanel.urls.first!
                    }
                }
            }

            if supportedPlatforms == nil {
                HStack {
                    Text("Choose the game's native platform:")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Picker("Choose the game's native platform:", selection: $platform) {
                    ForEach(supportedPlatforms!, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .onChange(of: platform) {
                    Task {
                        await fetchOptionalPacks()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary {
                withAnimation {
                    supportedPlatforms = fetchedPlatforms.keys
                        .compactMap { key in
                            switch key {
                            case "Windows": return .windows
                            case "Mac": return .macOS
                            default: return nil
                            }
                        }
                }

                if let platforms = supportedPlatforms {
                    platform = platforms.contains(.macOS) ? .macOS : .windows
                }

                if let supportedPlatforms = supportedPlatforms,
                   let firstPlatform = supportedPlatforms.first {
                    platform = firstPlatform
                }

                await fetchOptionalPacks()
            } else {
                Logger.app.info("Unable to fetch supported platforms for \"\(game.title)\".")
            }
        }

        HStack {
            Button("Close") {
                isPresented = false
            }

            Spacer()

            HStack {
                if let installSize = installSize, !fetchingOptionalPacks {
                    Text("\(String(format: "%.2f", Double(installSize * (1000000 / 1048576)) / (installSize > 1024 ? 1024 : 1))) \(installSize > 1024 ? "GB" : "MB")")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)
                }

                if fetchingOptionalPacks {
                    ProgressView()
                        .controlSize(.small)
                        .padding(0.5)
                }

                Button("Install") {
                    isPresented = false
                    Task(priority: .userInitiated) {
                        operation.queue.append(
                            GameOperation.InstallArguments(
                                game: game,
                                platform: platform,
                                type: .install,
                                optionalPacks: Array(selectedOptionalPacks),
                                baseURL: baseURL
                            )
                        )
                    }
                }
                .disabled(fetchingOptionalPacks)
                .buttonStyle(.borderedProminent)
                .disabled(installationError != nil)
            }
        }
    }
}

#Preview {
    InstallViewEvo(game: .constant(.init(source: .epic, title: "Fortnite (Test)", id: "Fortnite")), isPresented: .constant(true))
}
