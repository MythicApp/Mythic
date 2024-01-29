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
    
    @ObservedObject private var variables: VariableManager = .shared
    
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
    @State private var currentGame: Game = placeholderGame(.local) // FIXME: bad programming
    
    @State private var installableGames: [Game] = .init()
    @State private var installedGames: [Game] = .init()
    
    @State private var isInstallStatusViewPresented: Bool = false
    
    @State private var gameThumbnails: [String: String] = .init()
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
        
            if game.isLegendary && mode == .optionalPacks {
                group.enter()
                Task(priority: .userInitiated) {
                    let command = await Legendary.command(
                        args: ["install", game.appName], // force-unwraps rely on good codebase, don't fumble
                        useCache: true,
                        identifier: "parseOptionalPacks" // TODO: replace with metadata["dlcItemList"]
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
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 335))], spacing: 15) {
                if dataFetched {
                    ForEach(Array(installableGames.enumerated().filter {
                        searchText.isEmpty || $0.element.title.localizedCaseInsensitiveContains(searchText)
                    }), id: \.element.self) { index, game in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.background)
                                .frame(width: 220, height: 335)
                                .offset(y: -5)
                            
                            VStack {
                                CachedAsyncImage(
                                    url: URL(
                                        string: game.isLegendary
                                        ? gameThumbnails[game.appName] ?? .init()
                                        : game.imageURL?.path ?? .init()
                                    ),
                                    urlCache: gameImageURLCache
                                ) { phase in
                                    switch phase {
                                    case .empty:
                                        if let thumbnail = gameThumbnails[game.appName] ?? game.imageURL?.path,
                                           !thumbnail.isEmpty {
                                            ProgressView()
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
                                
                                HStack {
                                    // MARK: For installed games
                                    if installedGames.contains(game) {
                                        if variables.getVariable("launching_\(game.appName)") != true {
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
                                            .help("Game Settings")
                                            
                                            // MARK: Update Button
                                            if game.isLegendary, Legendary.needsUpdate(game: game) {
                                                Button {
                                                    Task(priority: .userInitiated) {
                                                        updateCurrentGame(game: game, mode: .normal)
                                                        
                                                        _ = try await Legendary.install(
                                                            game: game, // TODO: better update implementation; rushing to launch
                                                            platform: try Legendary.getGamePlatform(game: game)
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
                                                .help("Update available!")
                                            }
                                            
                                            if game.isLegendary,
                                               let json = try? JSON(data: Data(contentsOf: URL(filePath: "\(Legendary.configLocation)/installed.json"))),
                                               let needsVerification = json[game.appName]["needs_verification"].bool, // FIXME: force unwrap
                                               needsVerification {
                                                // MARK: Verification Button
                                                Button(action: {
                                                    updateCurrentGame(game: game, mode: .normal)
                                                    Task {
                                                        do {
                                                            try await Legendary.install(
                                                                game: game,
                                                                platform: json[game.appName]["platform"].string == "Mac" ? .macOS : .windows,
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
                                                            if let defaultBottle = Wine.allBottles?["Default"] {
                                                                if game.isLegendary {
                                                                    try await Legendary.launch(
                                                                        game: game,
                                                                        bottle: defaultBottle
                                                                    )
                                                                } else {
                                                                    try await LocalGames.launch(
                                                                        game: game,
                                                                        bottle: defaultBottle // TODO: FIXME: Add userdefaults option for prefix, include whether its writeable before creation
                                                                    )
                                                                }
                                                            } else {
                                                                throw NSError()
                                                            }
                                                        } catch {
                                                            LaunchError.game = game
                                                            LaunchError.message = "\(error.localizedDescription)"
                                                            activeAlert = .launchError
                                                            isAlertPresented = true
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "play.fill") // .disabled when game is running
                                                        .foregroundStyle(.green)
                                                        .padding()
                                                }
                                                .buttonStyle(.plain)
                                                .controlSize(.large)
                                                .help("Launch \(game.title)")
                                            }
                                            
                                            // MARK: Delete button
                                            Button {
                                                updateCurrentGame(game: game, mode: .normal)
                                                if game.isLegendary {
                                                    isUninstallViewPresented = true
                                                } else {
                                                    var library = LocalGames.library // TODO: add support to remove game
                                                    library?.removeAll { $0 == game }
                                                    LocalGames.library = library // FIXME: possible for split second to add new and overwrite one, extremely unlikely though
                                                    isRefreshCalled = true
                                                }
                                            } label: {
                                                Image(systemName: "xmark.bin.fill") // TODO: support for uninstalling local games
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            .help("Uninstall \(game.title)")
                                        } else {
                                            ProgressView()
                                                .controlSize(.small)
                                                .padding()
                                        }
                                    } else { // MARK: For games that aren't installed
                                        // MARK: Game Installation View
                                        if variables.getVariable("installing") == game { // TODO: Add for verificationStatus // TODO: turn this VStack into a separate view so it's the same in Main and GameList
                                            Button {
                                                isInstallStatusViewPresented = true
                                            } label: {
                                                if let installStatus: [String: [String: Any]] = variables.getVariable("installStatus"),
                                                   let percentage: Double = (installStatus["progress"])?["percentage"] as? Double {
                                                    ProgressView(value: percentage, total: 100)
                                                        .progressViewStyle(.linear)
                                                        .help("\(Int(percentage))% complete")
                                                } else {
                                                    ProgressView()
                                                        .progressViewStyle(.linear)
                                                        .help("Starting installation")
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button {
                                                activeAlert = .stopDownloadWarning
                                                isAlertPresented = true
                                            } label: {
                                                Image(systemName: "stop.fill")
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.regular)
                                            
                                            .onChange(of: variables.getVariable("installing") as Game?) { _, newValue in
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
                                                    .disabled(variables.getVariable("installing") as Game? != nil) // FIXME: doesnt work, check for installing_ var instead
                                            }
                                            .shadow(color: .gray, radius: 10, x: 1, y: 1)
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            .help("Download \(game.title)")
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
        
        .task { isRefreshCalled = true }
        
        .onReceive(Just(isRefreshCalled)) { called in
            if called {
                Logger.app.info("Received refresh call for GameListView")
                isProgressViewSheetPresented = true
                dataFetched = false
                
                let group = DispatchGroup()
                
                group.enter()
                Task(priority: .userInitiated) {
                    let games = (try? await Legendary.getInstallable()) ?? .init()
                    if !games.isEmpty { installableGames = games + (LocalGames.library ?? .init()) }
                    group.leave()
                }
                
                group.enter()
                Task(priority: .userInitiated) {
                    let thumbnails = (try? await Legendary.getImages(imageType: .tall)) ?? .init()
                    if !thumbnails.isEmpty { gameThumbnails = thumbnails }
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
                game: $currentGame,
                gameThumbnails: $gameThumbnails
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
        
        .sheet(isPresented: $isPlayDefaultViewPresented) {
            GameListView.PlayDefaultView(
                isPresented: $isPlayDefaultViewPresented,
                game: $currentGame,
                isGameListRefreshCalled: $isRefreshCalled
            )
        }
        
        .sheet(isPresented: $isInstallStatusViewPresented) {
            InstallStatusView(isPresented: $isInstallStatusViewPresented)
        }
        
        .alert(isPresented: $isAlertPresented) {
            switch activeAlert {
            case .installError: // used in other scripts, will unify (TODO: unify)
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
                stopGameModificationAlert(isPresented: $isAlertPresented, game: variables.getVariable("installing"))
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
}
