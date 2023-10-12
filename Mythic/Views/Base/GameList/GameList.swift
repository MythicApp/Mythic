//
//  GameList.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/9/2023.
//

import Foundation
import SwiftUI
import CachedAsyncImage
import OSLog
import SwiftyJSON
import Combine

struct GameListView: View {
    
    @Binding var isRefreshCalled: Bool
    
    @State private var isSettingsViewPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUninstallViewPresented: Bool = false
    
    @State private var isProgressViewSheetPresented: Bool = true
    @State private var currentGame: String = ""
    
    @State private var installableGames: [String] = []
    @State private var installedGames: [String] = []
    @StateObject private var installing = Legendary.Installing.shared
    
    @State private var gameThumbnails: [String: String] = [:]
    @State private var optionalPacks: [String: String] = [:]
    
    @State private var dataFetched: Bool = false
    
    enum UpdateCurrentGameMode {
        case normal
        case optionalPacks
    }
    
    func updateCurrentGame(game: String, mode: UpdateCurrentGameMode) {
        isProgressViewSheetPresented = true
        
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let title = Legendary.getTitleFromAppName(appName: game)
            DispatchQueue.main.async { [self] in
                currentGame = title
                group.leave()
            }
        }
        
        if mode == .optionalPacks {
            let haltCommand = DispatchSemaphore(value: 0)
            
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let command = Legendary.command(
                    args: ["install", game],
                    useCache: true,
                    halt: haltCommand
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
                
                print("optional packs: \(optionalPacks)")
                haltCommand.signal()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isProgressViewSheetPresented = false
        }
    }
    
    var body: some View {
        
        let imageCache = URLCache(
            memoryCapacity: 512_000_000, // 512 MB // RAM MAX
            diskCapacity: 3_000_000_000 // 3 GB // DISK MAX
        )
        
        ScrollView(.horizontal) {
            LazyHStack {
                if dataFetched {
                    ForEach(installableGames, id: \.self) { game in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.background)
                                .frame(width: 220, height: 325)
                                .offset(y: -10)
                            
                            VStack {
                                CachedAsyncImage(url: URL(string: gameThumbnails[game]!), urlCache: imageCache) { phase in
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
                                                .blur(radius: 30)
                                            
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
                                        Button(action: {
                                            updateCurrentGame(game: game, mode: .normal)
                                            isSettingsViewPresented = true
                                        }) {
                                            Image(systemName: "gear")
                                                .foregroundStyle(.gray)
                                                .padding()
                                        }
                                        .shadow(color: .gray, radius: 10, x: 1, y: 1)
                                        .buttonStyle(.plain)
                                        .controlSize(.large)
                                        
                                        Button(action: {
                                            updateCurrentGame(game: game, mode: .normal)
                                            _ = Legendary.command(args: ["launch", game], useCache: false)
                                        }) {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.green)
                                                .padding()
                                        }
                                        .shadow(color: .green, radius: 10, x: 1, y: 1)
                                        .buttonStyle(.plain)
                                        .controlSize(.large)
                                        
                                        Button(action: {
                                            updateCurrentGame(game: game, mode: .normal)
                                            isUninstallViewPresented = true
                                        }) {
                                            Image(systemName: "xmark.bin.fill")
                                                .foregroundStyle(.red)
                                                .padding()
                                        }
                                        .shadow(color: .red, radius: 10, x: 1, y: 1)
                                        .buttonStyle(.plain)
                                        .controlSize(.large)
                                    } else {
                                        if installing._value && installing._game == game {
                                            if installing._status.progress?.percentage == nil {
                                                ProgressView()
                                                    .progressViewStyle(.linear)
                                            } else {
                                                ProgressView(value: installing._status.progress?.percentage, total: 100)
                                                    .progressViewStyle(.linear)
                                                    .onChange(of: installing._status.progress?.percentage) { _, newValue in
                                                        if newValue == 100 {
                                                            isRefreshCalled = true
                                                        }
                                                    }
                                            }
                                            
                                            Button(action: {
                                                Logger.app.warning("Stop install not implemented yet; execute \"killall cli\" lol")
                                            }) {
                                                Image(systemName: "stop.fill")
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            .shadow(color: .red, radius: 10, x: 1, y: 1)
                                            .buttonStyle(.plain)
                                            .controlSize(.regular)
                                            
                                        } else {
                                            Button(action: {
                                                updateCurrentGame(game: game, mode: .optionalPacks)
                                                isInstallViewPresented = true
                                            }) {
                                                Image(systemName: "arrow.down.to.line")
                                                    .foregroundStyle(.gray)
                                                    .padding()
                                            }
                                            .shadow(color: .accent, radius: 10, x: 1, y: 1)
                                            .buttonStyle(.plain)
                                            .controlSize(.large)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        
        .onAppear {
            isRefreshCalled = true
        }
        
        .onReceive(Just(isRefreshCalled)) { called in
            if called {
                Logger.app.info("Recieved refresh call for GameListView")
                isProgressViewSheetPresented = true
                dataFetched = false
                
                let group = DispatchGroup()
                
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    let games = Legendary.getInstallable()
                    DispatchQueue.main.async { [self] in
                        installableGames = games.appNames
                        group.leave()
                    }
                }
                
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    let thumbnails = Legendary.getImages(imageType: .tall)
                    DispatchQueue.main.async { [self] in
                        gameThumbnails = thumbnails
                        group.leave()
                    }
                }
                
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    let installed = Legendary.getInstalledGames()
                    DispatchQueue.main.async { [self] in
                        installedGames = installed.appNames
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    isProgressViewSheetPresented = false
                    dataFetched = true
                }
                
                isRefreshCalled = false
            }
        }
        
        
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
                isGameListRefreshCalled: $isRefreshCalled
            )
        }
        
        .sheet(isPresented: $isUninstallViewPresented) {
            GameListView.UninstallView(
                isPresented: $isUninstallViewPresented,
                game: $currentGame,
                isGameListRefreshCalled: $isRefreshCalled
            )
        }
    }
}


#Preview {
    LibraryView()
}
