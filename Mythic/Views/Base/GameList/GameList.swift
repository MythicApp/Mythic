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

// MARK: - GameListView Struct
/// A SwiftUI view for displaying a list of installable games.
struct GameListView: View {
    
    // MARK: - Properties
    
    /// Binding to track if a refresh is called.
    @Binding var isRefreshCalled: Bool
    
    // MARK: - State Properties
    
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var isSettingsViewPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUninstallViewPresented: Bool = false
    @State private var isPlayDefaultViewPresented: Bool = false
    
    enum ActiveAlert {
        case installError, uninstallError, stopDownloadWarning
    }
    
    @State private var activeAlert: ActiveAlert = .installError
    @State private var isAlertPresented: Bool = false
    
    @State private var installationErrorMessage: String = String()
    @State private var uninstallationErrorMessage: Substring = Substring()
    @State private var failedGame: Legendary.Game?
    
    @State private var isProgressViewSheetPresented: Bool = true
    @State private var currentGame: Legendary.Game = .init(appName: String(), title: String())
    
    @State private var installableGames: [Legendary.Game] = Array()
    @State private var installedGames: [Legendary.Game] = Array()
    @StateObject private var installing = Legendary.Installing.shared
    
    @State private var isInstallStatusViewPresented: Bool = false
    
    @State private var gameThumbnails: [String: String] = Dictionary()
    @State private var optionalPacks: [String: String] = Dictionary()
    
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
    func updateCurrentGame(game: Legendary.Game, mode: UpdateCurrentGameMode) {
        isProgressViewSheetPresented = true
        
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { [self] in
                currentGame = game
                group.leave()
            }
        }
        
        if mode == .optionalPacks {
            group.enter()
            Task(priority: .userInitiated) {
                let command = await Legendary.command(
                    args: ["install", game.appName],
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
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 335))], spacing: 15) {
                if dataFetched {
                    ForEach(Array(installableGames.enumerated()), id: \.element.self) { index, game in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.background)
                                .frame(width: 220, height: 335)
                                .offset(y: -5)
                            
                            VStack {
                                CachedAsyncImage(
                                    url: URL(string: gameThumbnails[game.appName] ?? String()),
                                    urlCache: URLCache(memoryCapacity: 128_000_000, diskCapacity: 768_000_000) // in bytes
                                ) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        ZStack {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 200, height: 400/1.5)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                                .blur(radius: 20)
                                            
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 200, height: 400/1.5)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                        }
                                    case .failure:
                                        Image(systemName: "network.slash")
                                            .imageScale(.large)
                                    @unknown default:
                                        Image(systemName: "exclamationmark.triangle")
                                            .imageScale(.large)
                                    }
                                }
                                
                                HStack {
                                    if installedGames.contains(game) {
                                        if variables.getVariable("playing_\(game.title)") != true {
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
                                            
                                            Button {
                                                Task(priority: .userInitiated) {
                                                    updateCurrentGame(game: game, mode: .normal)
                                                    // swiftlint:disable:next force_try
                                                    try! await Legendary.launch(game: game, bottle: URL(filePath: Wine.defaultBottle.path)) // FIXME: horrible programming; not threadsafe at all
                                                }
                                            } label: {
                                                Image(systemName: "play.fill")
                                                    .foregroundStyle(.green)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                            
                                            Button {
                                                updateCurrentGame(game: game, mode: .normal)
                                                isUninstallViewPresented = true
                                            } label: {
                                                Image(systemName: "xmark.bin.fill")
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                        } else {
                                            ProgressView()
                                                .controlSize(.small)
                                                .padding()
                                        }
                                    } else {
                                        if installing._value && installing._game == game {
                                            Button {
                                                isInstallStatusViewPresented = true
                                            } label: {
                                                if installing._status.progress?.percentage == nil {
                                                    ProgressView()
                                                        .progressViewStyle(.linear)
                                                } else {
                                                    ProgressView(value: installing._status.progress?.percentage, total: 100)
                                                        .progressViewStyle(.linear)
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
                                            
                                            .onChange(of: installing._finished) { _, newValue in
                                                if newValue == true {
                                                    isRefreshCalled = true
                                                }
                                            }
                                            
                                        } else {
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
        }
        
        .onAppear {
            isRefreshCalled = true
        }
        
        .onReceive(Just(isRefreshCalled)) { called in
            if called {
                Logger.app.info("Received refresh call for GameListView")
                isProgressViewSheetPresented = true
                dataFetched = false
                
                let group = DispatchGroup()
                
                group.enter()
                Task(priority: .userInitiated) {
                    let games = (try? await Legendary.getInstallable()) ?? Array()
                    if !games.isEmpty { installableGames = games }
                    group.leave()
                }
                
                group.enter()
                Task(priority: .userInitiated) {
                    let thumbnails = (try? await Legendary.getImages(imageType: .tall)) ?? Dictionary()
                    if !thumbnails.isEmpty { gameThumbnails = thumbnails }
                    group.leave()
                }
                
                group.enter()
                Task(priority: .userInitiated) {
                    let installed = (try? Legendary.getInstalledGames()) ?? Array()
                    if !installed.isEmpty { installedGames = installed }
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
                game: currentGame
            )
        }
        
        .sheet(isPresented: $isInstallViewPresented) {
            GameListView.InstallView(
                isPresented: $isInstallViewPresented,
                game: currentGame,
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
                game: currentGame,
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
                game: currentGame,
                isGameListRefreshCalled: $isRefreshCalled
            )
        }
        
        .sheet(isPresented: $isInstallStatusViewPresented) {
            InstallStatusView(isPresented: $isInstallStatusViewPresented)
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
                stopDownloadAlert(isPresented: $isAlertPresented, game: Legendary.Installing.game)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameListView(isRefreshCalled: .constant(false))
}
