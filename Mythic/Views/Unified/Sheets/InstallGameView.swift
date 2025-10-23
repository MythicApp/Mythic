//
//  InstallGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 7/3/2024.
//

import SwiftUI
import OSLog

struct InstallViewEvo: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @State var optionalPacks: [String: String] = .init()
    @State var selectedOptionalPacks: Set<String> = .init()
    @State var fetchingOptionalPacks: Bool = false

    @State private var isInstallLocationFileImporterPresented: Bool = false

    @State var installSize: Double?

    @State private var supportedPlatforms: [Game.Platform]?
    @State var platform: Game.Platform = .macOS

    @State private var isInstallationErrorPresented: Bool = false
    @State private var installationError: Error?

    @AppStorage("installBaseURL") private var baseURL: URL = Bundle.appGames!
    @ObservedObject var operation: GameOperation = .shared

    private func fetchOptionalPacks() async {
        guard !fetchingOptionalPacks else { return }
        withAnimation { fetchingOptionalPacks = true }

        let consumer = await Legendary.executeStreamed(
            identifier: "parseOptionalPacks",
            arguments: [
                "install", game.id,
                "--platform", {
                    switch platform {
                    case .macOS: "Mac"
                    case .windows: "Windows"
                    }
                }()
            ],
            onChunk: { chunk in
                switch chunk.stream {
                case .standardError:
                    if chunk.output.contains("Install size:") {
                        if let match = try? Regex(#"Install size: (\d+(\.\d+)?) MiB"#).firstMatch(in: chunk.output) {
                            let sizeString = match[1].substring ?? ""
                            let sizeValue = Double(sizeString) ?? 0.0

                            Task {
                                await MainActor.run {
                                    installSize = sizeValue
                                }
                            }
                        }
                    }
                case .standardOutput:
                    if chunk.output.contains("The following optional packs are available") { // hate hardcoding
                        Logger.app.debug("Found optional packs")
                        chunk.output.enumerateLines { line, _ in
                            Logger.app.debug("Adding optional pack \"\(line)\"")
                            if let match = try? Regex(#"\s*\* (?<identifier>\w+) - (?<name>.+)"#).firstMatch(in: line) {
                                let id = String(match["identifier"]?.substring ?? "")
                                let name = String(match["name"]?.substring ?? "")

                                _ = withAnimation {
                                    Task {
                                        await MainActor.run {
                                            optionalPacks.updateValue(name, forKey: id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if chunk.output.contains("Do you wish to install") || chunk.output.contains("Additional packs") {
                        Task { @MainActor in
                            await Legendary.RunningCommands.shared.stop(id: "parseOptionalPacks")
                        }
                    }
                }

                return nil
            }
        )

        try? await consumer.value // await completion of task

        withAnimation { fetchingOptionalPacks = false }
    }

    var body: some View {
        Text("Install \"\(game.title)\"")
            .font(.title)
            .alert(isPresented: $isInstallationErrorPresented) {
                Alert(
                    title: .init("Unable to proceed with installation."),
                    message: .init(installationError?.localizedDescription ?? "Unknown Error."),
                    dismissButton: .default(.init("OK")) {
                        isPresented = false
                    }
                )
            }
            .onChange(of: isPresented) { _, newValue in // don't use .onDisappear, it interferes with runningcommands' task handling
                guard !newValue else { return }
                Task { @MainActor in
                    await Legendary.RunningCommands.shared.stop(id: "parseOptionalPacks")
                }
            }
            .padding([.horizontal, .top])

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
                    Image(systemName: "exclamationmark.triangle")
                        .symbolVariant(.fill)
                        .help("Folder is not writable.")
                }

                // TODO: unify
                Button("Browse...") {
                    isInstallLocationFileImporterPresented = true
                }
                .fileImporter(
                    isPresented: $isInstallLocationFileImporterPresented,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result {
                        baseURL = url // FIXME: this overrides the default base URL, which is not ideal
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
                    platform = platforms.contains(.macOS) ? .macOS : (supportedPlatforms?.first ?? .windows)
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
                .disabled(supportedPlatforms == nil)
                .disabled(fetchingOptionalPacks)
                .disabled(installationError != nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding([.horizontal, .bottom])
    }
}

#Preview {
    InstallViewEvo(game: .constant(.init(source: .epic, title: "Fortnite (Test)", id: "Fortnite")), isPresented: .constant(true))
}
