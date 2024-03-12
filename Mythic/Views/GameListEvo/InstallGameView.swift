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
    
    @State private var supportedPlatforms: [GamePlatform]?
    @State var platform: GamePlatform = .macOS
    
    @AppStorage("installBaseURL") private var baseURL: URL = Bundle.appGames!
    @ObservedObject private var gameModification: GameModification = .shared
    
    @State private var isInstallErrorPresented: Bool = false
    @State private var installError: Error?
    
    var body: some View {
        Text("Install \"\(game.title)\"")
            .font(.title)
            .task(priority: .userInitiated) {
                fetchingOptionalPacks = true
                defer { fetchingOptionalPacks = false }
                
                let command = await Legendary.command(
                    args: ["install", game.appName],
                    useCache: true,
                    identifier: "parseOptionalPacks"
                )
                
                guard let stdoutString = String(data: command.stdout, encoding: .utf8) else { return }
                guard stdoutString.contains("The following optional packs are available (tag - name):") else { return }
                
                for line in stdoutString.components(separatedBy: "\n") where line.hasPrefix(" * ") {
                    let components = line
                        .trimmingPrefix(" * ")
                        .split(separator: " - ", maxSplits: 1)
                        .map { String($0) } // convert the substrings to regular strings
                    
                    if components.count >= 2 {
                        let tag = components[0].trimmingCharacters(in: .whitespaces)
                        let name = components[1].trimmingCharacters(in: .whitespaces)
                        optionalPacks[name] = tag
                    }
                }
            }
        
        if !optionalPacks.isEmpty {
            Text("(supports selective downloads.)")
                .font(.footnote)
                .foregroundStyle(.placeholder)
            
            Form {
                ForEach(optionalPacks.sorted(by: { $0.key < $1.key }), id: \.key) { name, tag in
                    HStack {
                        VStack {
                            Text(name)
                            Text(tag)
                                .font(.footnote)
                                .foregroundStyle(.placeholder)
                                .multilineTextAlignment(.leading)
                        }
                        
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
                    HStack { // FIXME: jank
                        Text("Where do you want the game's base path to be located?")
                        Spacer()
                    }
                    HStack {
                        Text(baseURL.prettyPath())
                            .foregroundStyle(.placeholder)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                if !FileLocations.isWritableFolder(url: baseURL) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .help("Folder is not writable.")
                }
                
                // TODO: unify
                Button("Browse...") { // TODO: replace with .fileImporter
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
                Picker("Choose the game's native platform:", selection: $platform) { // FIXME: some games dont have macos binaries
                    ForEach(supportedPlatforms!, id: \.self) {
                        Text($0.rawValue).tag($0)
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
                if fetchingOptionalPacks {
                    ProgressView()
                        .controlSize(.small)
                        .padding(0.5)
                }
                    
                Button("Install") {
                    isPresented = false
                    Task(priority: .userInitiated) {
                        do {
                            try await Legendary.install(
                                game: game,
                                platform: platform,
                                optionalPacks: Array(selectedOptionalPacks),
                                baseURL: baseURL
                            )
                            // isGameListRefreshCalled = true
                        } catch {
                            installError = error
                            isInstallErrorPresented = true
                        }
                    }
                }
                .disabled(fetchingOptionalPacks)
                .buttonStyle(.borderedProminent)
            }
            .alert(isPresented: $isInstallErrorPresented) {
                Alert(
                    title: .init("Error installing \"\(game.title)\"."),
                    message: .init(installError?.localizedDescription ?? "Unknown Error.")
                )
            }
        }
    }
}

#Preview {
    InstallViewEvo(game: .constant(placeholderGame(type: .local)), isPresented: .constant(true))
}
