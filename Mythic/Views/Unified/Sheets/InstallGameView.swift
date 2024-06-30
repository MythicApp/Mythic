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
    
    @State private var supportedPlatforms: [GamePlatform]?
    @State var platform: GamePlatform = .macOS
    
    @State private var isInstallationErrorPresented: Bool = false
    @State private var installationError: Error?
    
    @AppStorage("installBaseURL") private var baseURL: URL = Bundle.appGames!
    @ObservedObject var operation: GameOperation = .shared
    
    var body: some View {
        Text("Install \"\(game.title)\"")
            .font(.title)
            .task(priority: .userInitiated) {
                fetchingOptionalPacks = true
                
                try? await Legendary.command(arguments: ["install", game.id], identifier: "parseOptionalPacks") { output in
                    
                    if output.stdout.contains("Installation requirements check returned the following results:") {
                        if let match = try? Regex(#"Failure: (.*)"#).firstMatch(in: output.stdout) {
                            Legendary.stopCommand(identifier: "install")
                            installationError = Legendary.InstallationError(errorDescription: .init(match.last?.substring ?? "Unknown Error"))
                            isInstallationErrorPresented = true
                            return
                        }
                    }
                    
                    if output.stdout.contains("Do you wish to install") || output.stdout.contains("Additional packs") {
                        Legendary.runningCommands["parseOptionalPacks"]?.terminate(); return
                    }
                    
                    if output.stdout.contains("The following optional packs are available") { // hate hardcoding
                        print("optipacks found")
                        output.stdout.enumerateLines { line, _ in
                            print("optipack enum \(line)")
                            if let match = try? Regex(#"\s*\* (?<identifier>\w+) - (?<name>.+)"#).firstMatch(in: line) {
                                optionalPacks.updateValue(String(match["name"]?.substring ?? .init()), forKey: String(match["identifier"]?.substring ?? .init()))
                            }
                        }
                    }
                    
                    if output.stderr.contains("Install size:") {
                        if let match = try? Regex(#"Install size: (\d+(\.\d+)?) MiB"#).firstMatch(in: output.stderr) {
                            installSize = Double(match[1].substring ?? "") ?? 0.0
                        }
                    }
                }
                
                fetchingOptionalPacks = false
            }
            .alert(isPresented: $isInstallationErrorPresented) {
                Alert(
                    title: .init("Unable to proceed with installation."),
                    message: .init(installationError?.localizedDescription ?? "Unknown error."),
                    dismissButton: .default(.init("OK")) {
                        isPresented = false
                    }
                )
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
                        Text("""
                        \(name)
                        \(
                        Text(tag)
                            .font(.footnote)
                            .foregroundStyle(.placeholder)
                        )
                        """)
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
                VStack {
                    HStack {
                        Text("""
                        Where do you want the game's base path to be located?
                        \(
                        Text(baseURL.prettyPath())
                            .foregroundStyle(.placeholder)
                        )
                        """)
                        Spacer()
                    }
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
            }
        }
        .formStyle(.grouped)
        .task {
            if let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary {
                supportedPlatforms = fetchedPlatforms.keys
                    .compactMap { key in
                        switch key {
                        case "Windows": return .windows
                        case "Mac": return .macOS
                        default: return nil
                        }
                    }
                
                platform = supportedPlatforms!.first!
            } else {
                Logger.app.info("Unable to fetch supported platforms for \(game.title).")
            }
        }
        
        HStack {
            Button("Close") {
                isPresented = false
            }
            
            Spacer()
            
            HStack {
                if let installSize = installSize {
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
    InstallViewEvo(game: .constant(.init(type: .local, title: .init())), isPresented: .constant(true))
}
