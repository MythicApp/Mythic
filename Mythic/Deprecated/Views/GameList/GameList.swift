//
//  GameList.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI
import CachedAsyncImage
import OSLog
import SwiftyJSON
import Combine

/// ViewModifier that enables views to have a fade in effect
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    opacity = 1
                }
            }
    }
}

// MARK: - GameListView Struct
/// A SwiftUI view for displaying a list of installable games.
struct GameListView: View {
    
    // MARK: - Properties
    
    /// Binding to track if a refresh is called.
    @Binding var isRefreshCalled: Bool
    
    @Binding var searchText: String
    
    // MARK: - State Properties
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var gameModification: GameModification = .shared
    @AppStorage("minimiseOnGameLaunch") private var minimizeOnGameLaunch: Bool = false
    
    @State private var isSettingsViewPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUninstallViewPresented: Bool = false
    @State private var isPlayDefaultViewPresented: Bool = false
    
    enum ActiveAlert {
        case installError,
             uninstallError,
             stopDownloadWarning,
             launchError
    }
    
    struct LaunchError {
        static var message: String = .init()
        static var game: Game? = nil // swiftlint:disable:this redundant_optional_initialization
    }
    
    @State private var activeAlert: ActiveAlert = .installError
    @State private var isAlertPresented: Bool = false
    
    @State private var installationErrorMessage: String = .init()
    @State private var uninstallationErrorMessage: Substring = .init()
    @State private var failedGame: Game?
    
    @State private var isProgressViewSheetPresented: Bool = true
    @State private var currentGame: Game = placeholderGame(type: .local)
    
    @State private var installableGames: [Game] = .init()
    @State private var installedGames: [Game] = .init()
    
    @State private var isInstallStatusViewPresented: Bool = false
    
    @State private var optionalPacks: [String: String] = .init()
    
    @State private var dataFetched: Bool = false
    
    // MARK: - Enumerations
    /// Enumeration for updating the current game.
    enum UpdateCurrentGameMode {
        case normal
        case optionalPacks
    }
    
    // MARK: - UpdateCurrentGame Method
    /**
     Updates the current game based on the specified mode.
     
     - Parameter game: The game to set as the current game.
     - Parameter mode: The mode for updating the current game.
     */
    func updateCurrentGame(game: Game, mode: UpdateCurrentGameMode) {
        isProgressViewSheetPresented = true
        
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { [self] in
                currentGame = game
                group.leave()
            }
        }
        
        if game.type == .epic && mode == .optionalPacks {
            group.enter()
            Task(priority: .userInitiated) {
                let command = await Legendary.command(
                    args: ["install", game.id],
                    useCache: true,
                    identifier: "parseOptionalPacks"
                )
                
                var isParsingOptionalPacks = false
                
                for line in String(data: command.stdout, encoding: .utf8)!.components(separatedBy: "\n") {
                    if isParsingOptionalPacks {
                        if line.isEmpty || !line.hasPrefix(" * ") { break }
                        
                        let cleanedLine = line.trimmingPrefix(" * ")
                        let components = cleanedLine.split(separator: " - ", maxSplits: 1)
                            .map { String($0) } // convert the substrings to regular strings
                        
                        if components.count >= 2 {
                            let tag = components[0].trimmingCharacters(in: .whitespaces)
                            let name = components[1].trimmingCharacters(in: .whitespaces)
                            optionalPacks[name] = tag
                        }
                    } else if line.contains("The following optional packs are available (tag - name):") {
                        isParsingOptionalPacks = true
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isProgressViewSheetPresented = false
        }
    }
    
    // MARK: - Body View
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 335))], spacing: 15) { // also lazyloads images
                if dataFetched {
                    ForEach(Array(installableGames.enumerated().filter {
                        searchText.isEmpty || $0.element.title.localizedCaseInsensitiveContains(searchText)
                    }), id: \.element.self) { index, game in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.background)
                                .frame(width: 220, height: 335)
                            
                            VStack {
                                if let gamePath = game.path, game.imageURL == nil && game.platform == .macOS {
                                    ZStack {
                                        Image(nsImage: workspace.icon(forFile: gamePath)) // FIXME: fix image stretching and try to zoom instead
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .blur(radius: 20)
                                            .frame(width: 200)
                                        
                                        Image(nsImage: workspace.icon(forFile: gamePath))
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .modifier(FadeInModifier())
                                            .frame(width: 200)
                                    }
                                    .frame(width: 200, height: 400/1.5)
                                } else {
                                    CachedAsyncImage(
                                        url: game.type == .epic
                                        ? .init(string: Legendary.getImage(of: game, type: .tall)) // TODO: if there is no local game image for a game, check if Legendary.getImage supports it
                                        : game.imageURL
                                    ) { phase in
                                        switch phase {
                                        case .empty:
                                            if !Legendary.getImage(of: game, type: .tall).isEmpty || ((game.imageURL?.path(percentEncoded: false).isEmpty) != nil) {
                                                VStack {
                                                    Spacer()
                                                    HStack {
                                                        if networkMonitor.isEpicAccessible {
                                                            ProgressView()
                                                                .controlSize(.small)
                                                                .padding(.trailing, 5)
                                                        } else {
                                                            Image(systemName: "network.slash")
                                                                .symbolEffect(.pulse)
                                                                .foregroundStyle(.red)
                                                                .help("Mythic cannot connect to the internet.")
                                                        }
                                                        Text("(\(game.title))")
                                                            .truncationMode(.tail)
                                                            .foregroundStyle(.placeholder)
                                                    }
                                                }
                                                .frame(width: 200, height: 400/1.5)
                                            } else {
                                                Text("\(game.title)")
                                                    .font(.largeTitle)
                                                    .frame(width: 200, height: 400/1.5)
                                            }
                                        case .success(let image):
                                            ZStack {
                                                image
                                                    .resizable()
                                                    .frame(width: 200, height: 400/1.5)
                                                    .aspectRatio(3/4, contentMode: .fit)
                                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                                    .blur(radius: 20)
                                                
                                                image
                                                    .resizable()
                                                    .frame(width: 200, height: 400/1.5)
                                                    .aspectRatio(3/4, contentMode: .fit)
                                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                                    .modifier(FadeInModifier())
                                            }
                                        case .failure:
                                            Text("\(game.title)")
                                                .font(.largeTitle)
                                                .frame(width: 200, height: 400/1.5)
                                        @unknown default:
                                            Image(systemName: "exclamationmark.triangle")
                                                .symbolEffect(.appear)
                                                .imageScale(.large)
                                                .frame(width: 200, height: 400/1.5)
                                        }
                                    }
                                }
                                
                                HStack {
                                    // MARK: For installed games
                                    if installedGames.contains(game) {
                                        if variables.getVariable("launching_\(game.id)") != true { // TODO: deprecate
                                            // MARK: Settings icon
                                            Button {
                                                updateCurrentGame(game: game, mode: .normal)
                                                isSettingsViewPresented = true
                                            } label: {
                                                Image(systemName: "gear")
                                                    .foregroundStyle(.gray)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            .help("\(game.title) Settings")
                                            
                                            // MARK: Update Button
                                            if game.type == .epic, Legendary.needsUpdate(game: game) {
                                                Button {
                                                    Task(priority: .userInitiated) {
                                                        updateCurrentGame(game: game, mode: .normal)
                                                        
                                                        try await Legendary.install(
                                                            game: game,
                                                            platform: try Legendary.getGamePlatform(game: game),
                                                            type: .update
                                                        )
                                                        
                                                        isRefreshCalled = true
                                                    }
                                                } label: {
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                        .foregroundStyle(.blue)
                                                        .padding()
                                                }
                                                .buttonStyle(.plain)
                                                .controlSize(.large)
                                                .disabled(!networkMonitor.isEpicAccessible)
                                                .help(networkMonitor.isEpicAccessible ? "Update \(game.title)" : "Connect to the internet to update \(game.title).")
                                            }
                                            
                                            if game.type == .epic,
                                               let json = try? JSON(data: Data(contentsOf: URL(filePath: "\(Legendary.configLocation)/installed.json"))),
                                               let needsVerification = json[game.id]["needs_verification"].bool, // FIXME: force unwrap
                                               needsVerification {
                                                // MARK: Verification Button
                                                Button(action: {
                                                    updateCurrentGame(game: game, mode: .normal)
                                                    Task {
                                                        do {
                                                            try await Legendary.install(
                                                                game: game,
                                                                platform: json[game.id]["platform"].string == "Mac" ? .macOS : .windows,
                                                                type: .repair
                                                            )
                                                            
                                                            isRefreshCalled = true
                                                        } catch {
                                                            Logger.app.error("Unable to verify \(game.title): \(error.localizedDescription)") // TODO: implement visual error
                                                        }
                                                    }
                                                }, label: {
                                                    Image(systemName: "checkmark.gobackward")
                                                        .foregroundStyle(.orange)
                                                        .padding()
                                                })
                                                .buttonStyle(.plain)
                                                .controlSize(.large)
                                                .help("Game integrity verification is required.")
                                            } else {
                                                // MARK: Play Button
                                                Button { // TODO: play or update & play popover
                                                    Task(priority: .userInitiated) {
                                                        updateCurrentGame(game: game, mode: .normal)
                                                        do {
                                                            switch game.type {
                                                            case .epic:
                                                                if Engine.exists {
                                                                    try await Legendary.launch(
                                                                        game: game,
                                                                        bottle: Wine.allBottles![game.bottleName]!,
                                                                        online: networkMonitor.isEpicAccessible
                                                                    )
                                                                } else {
                                                                    let app = MythicApp() // FIXME: is this dangerous or just stupid
                                                                    app.onboardingChapter = .engineDisclaimer
                                                                    app.isFirstLaunch = true
                                                                }
                                                            case .local:
                                                                try await LocalGames.launch(
                                                                    game: game,
                                                                    bottle: Wine.allBottles![game.bottleName]!
                                                                )
                                                            }
                                                            
                                                            if minimizeOnGameLaunch { NSApp.windows.first?.miniaturize(nil) }
                                                        } catch {
                                                            LaunchError.game = game
                                                            LaunchError.message = "\(error.localizedDescription)"
                                                            activeAlert = .launchError
                                                            isAlertPresented = true
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: Engine.exists ? "play.fill" : "arrow.down.circle.dotted") // .disabled when game is running
                                                        .foregroundStyle(Engine.exists ? .green : .orange)
                                                        .padding()
                                                }
                                                .buttonStyle(.plain)
                                                .controlSize(.large)
                                                .help("Launch \(game.title)")
                                            }
                                            
                                            // MARK: Delete button
                                            Button {
                                                updateCurrentGame(game: game, mode: .normal)
                                                switch game.type {
                                                case .epic:
                                                    isUninstallViewPresented = true
                                                case .local:
                                                    LocalGames.library = LocalGames.library?.filter { $0 != game }
                                                    isRefreshCalled = true
                                                }
                                            } label: {
                                                Image(systemName: "xmark.bin.fill") // TODO: support for uninstalling local games
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            .help("Uninstall \"\(game.title)\"")
                                        } else {
                                            ProgressView()
                                                .controlSize(.small)
                                                .padding()
                                        }
                                    } else { // MARK: For games that aren't installed
                                        // MARK: Game Installation View
                                        // FIXME: can also happen during updates and that doesnt show
                                        if gameModification.game == game {
                                            InstallationProgressView()
                                                .padding()
                                            
                                            .onChange(of: gameModification.game) { _, newValue in
                                                isRefreshCalled = (newValue == nil)
                                            }
                                        } else {
                                            // MARK: Game Download button
                                            Button {
                                                updateCurrentGame(game: game, mode: .optionalPacks)
                                                isInstallViewPresented = true
                                            } label: {
                                                Image(systemName: "arrow.down.to.line")
                                                    .foregroundStyle(.gray)
                                                    .padding()
                                            }
                                            .shadow(color: .gray, radius: 10, x: 1, y: 1)
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            .disabled(gameModification.game != nil)
                                            .disabled(!networkMonitor.isEpicAccessible)
                                            .help(networkMonitor.isEpicAccessible ? "Download \(game.title)" : "Connect to the internet to download \(game.title).")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .padding(.leading, index == 0 ? 15 : 0)
                    }
                }
            }
            .searchable(text: $searchText, placement: .toolbar)
        }
        
        .task(priority: .userInitiated) { isRefreshCalled = true }
        
        .onReceive(Just(isRefreshCalled)) { called in
            if called {
                Logger.app.debug("Received refresh call for GameListView")
                isProgressViewSheetPresented = true
                dataFetched = false
                
                let group = DispatchGroup()
                
                group.enter()
                Task(priority: .userInitiated) {
                    let games = (try? Legendary.getInstallable()) ?? .init()
                    if !games.isEmpty { installableGames = games + (LocalGames.library ?? .init()) }
                    group.leave()
                }
                
                group.enter()
                Task(priority: .userInitiated) {
                    let installed = (try? Legendary.getInstalledGames()) ?? .init()
                    if !installed.isEmpty { installedGames = installed + (LocalGames.library ?? .init())}
                    group.leave()
                }
                
                group.notify(queue: .main) {
                    isProgressViewSheetPresented = false
                    dataFetched = true
                }
                
                isRefreshCalled = false
            }
        }
        
        // MARK: - Other Properties
        
        .sheet(isPresented: $isProgressViewSheetPresented) {
            ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
        }
        
        .sheet(isPresented: $isSettingsViewPresented) {
            GameListView.SettingsView(
                isPresented: $isSettingsViewPresented,
                game: $currentGame
            )
        }
        
        .sheet(isPresented: $isInstallViewPresented) {
            GameListView.InstallView(
                isPresented: $isInstallViewPresented,
                game: $currentGame,
                optionalPacks: $optionalPacks,
                isGameListRefreshCalled: $isRefreshCalled,
                isAlertPresented: $isAlertPresented,
                activeAlert: $activeAlert,
                installationErrorMessage: $installationErrorMessage,
                failedGame: $failedGame
            )
        }
        
        .sheet(isPresented: $isUninstallViewPresented) {
            GameListView.UninstallView(
                isPresented: $isUninstallViewPresented,
                game: $currentGame,
                isGameListRefreshCalled: $isRefreshCalled,
                activeAlert: $activeAlert,
                isAlertPresented: $isAlertPresented,
                failedGame: $failedGame,
                uninstallationErrorMessage: $uninstallationErrorMessage
            )
        }
        
        .sheet(isPresented: $isInstallStatusViewPresented) {
            InstallStatusView(isPresented: $isInstallStatusViewPresented)
                .padding()
        }
        
        .alert(isPresented: $isAlertPresented) {
            switch activeAlert {
            case .installError:
                Alert(
                    title: Text("Error installing \(failedGame?.title ?? "game")."),
                    message: Text(installationErrorMessage)
                )
            case .uninstallError:
                Alert(
                    title: Text("Error uninstalling \(failedGame?.title ?? "game")."),
                    message: Text(uninstallationErrorMessage)
                )
            case .stopDownloadWarning:
                stopGameOperationAlert(isPresented: $isAlertPresented, game: gameModification.game)
            case .launchError:
                Alert(
                    title: Text("Error launching \(LaunchError.game?.title ?? "game")."),
                    message: Text(LaunchError.message)
                )
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
