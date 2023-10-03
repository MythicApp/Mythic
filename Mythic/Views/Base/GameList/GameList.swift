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

struct GameListView: View {
    
    @State private var isSettingsViewPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUninstallViewPresented: Bool = false
    @State private var isDownloadViewPresented: Bool = false
    
    @State private var isProgressViewSheetPresented: Bool = true
    @State private var currentGame: String = ""
    
    @State private var installableGames: [String] = []
    @State private var gameThumbnails: [String: String] = [:]
    @State private var installedGames: [String] = []
    
    @State private var dataFetched: Bool = false
    
    func updateCurrentGame(game: String) {
        isProgressViewSheetPresented = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let title = LegendaryJson.getTitleFromAppName(appName: game)
            DispatchQueue.main.async { [self] in
                currentGame = title
                isProgressViewSheetPresented = false
            }
        }
    }
    
    public func updateAll() {
        isProgressViewSheetPresented = true
        dataFetched = false
        
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let games = LegendaryJson.getInstallable()
            DispatchQueue.main.async { [self] in
                installableGames = games.appNames
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let thumbnails = LegendaryJson.getImages()
            DispatchQueue.main.async { [self] in
                gameThumbnails = thumbnails
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let installed = LegendaryJson.getGames()
            DispatchQueue.main.async { [self] in
                installedGames = installed.appNames
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isProgressViewSheetPresented = false
            dataFetched = true
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
                                ZStack {
                                    // blur effect
                                    CachedAsyncImage(url: URL(string: gameThumbnails[game]!), urlCache: imageCache) { phase in
                                        if case .success(let image) = phase {
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                        }
                                    }
                                    .frame(width: 200, height: 400/1.5)
                                    .blur(radius: 30)
                                    
                                    // actual image
                                    CachedAsyncImage(url: URL(string: gameThumbnails[game]!), urlCache: imageCache) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                        case .failure:
                                            Image(systemName: "network.slash")
                                        @unknown default:
                                            Image(systemName: "exclamationmark.triangle")
                                        }
                                    }
                                    .frame(width: 200, height: 400/1.5)
                                }
                                
                                HStack {
                                    if installedGames.contains(game) {
                                        Button(action: {
                                            updateCurrentGame(game: game)
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
                                            updateCurrentGame(game: game)
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
                                            updateCurrentGame(game: game)
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
                                        Button(action: {
                                            updateCurrentGame(game: game)
                                            isDownloadViewPresented = true
                                        }) {
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
                            .padding()
                        }
                    }
                }
            }
        }
        
        .onAppear {
            updateAll()
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
                game: $currentGame
            )
        }
        
        .sheet(isPresented: $isUninstallViewPresented) {
            GameListView.UninstallView(
                isPresented: $isUninstallViewPresented,
                game: $currentGame
            )
        }
        
        .sheet(isPresented: $isDownloadViewPresented) {
            GameListView.DownloadView(
                isPresented: $isDownloadViewPresented,
                game: $currentGame
            )
        }
        
    }
}


#Preview {
    GameListView()
}
