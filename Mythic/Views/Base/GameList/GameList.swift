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
    @State private var isPlayDefaultViewPresented: Bool = false

    enum ActiveAlert { case installError, uninstallError }
    @State private var activeAlert: ActiveAlert = .installError
    @State private var isAlertPresented: Bool = false

    @State private var installationErrorMessage: String = String()
    @State private var uninstallationErrorMessage: Substring = Substring()
    @State private var failedGame: Legendary.Game? = nil

    @State private var isProgressViewSheetPresented: Bool = true
    @State private var currentGame: Legendary.Game = .init(appName: String(), title: String())

    @State private var installableGames: [Legendary.Game] = Array()
    @State private var installedGames: [Legendary.Game] = Array()
    @StateObject private var installing = Legendary.Installing.shared

    @State private var gameThumbnails: [String: String] = Dictionary()
    @State private var optionalPacks: [String: String] = Dictionary()

    @State private var dataFetched: Bool = false

    enum UpdateCurrentGameMode {
        case normal
        case optionalPacks
    }

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
                    useCache: true
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
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 335))], spacing: 15) {
                if dataFetched {
                    ForEach(Array(installableGames.enumerated()), id: \.element.self) { index, game in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.background)
                                .frame(width: 220, height: 335)
                                .offset(y: -5)

                            VStack {
                                CachedAsyncImage(url: URL(string: gameThumbnails[game.appName]!), urlCache: imageCache) { phase in
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
                                        Button(action: {
                                            updateCurrentGame(game: game, mode: .normal)
                                            isSettingsViewPresented = true
                                        }) {
                                            Image(systemName: "gear")
                                                .foregroundStyle(.gray)
                                                .padding()
                                        }
                                        // .shadow(color: .gray, radius: 10, x: 1, y: 1)
                                        .buttonStyle(.plain)
                                        .controlSize(.large)

                                        Button(action: {
                                            Task(priority: .userInitiated) {
                                                updateCurrentGame(game: game, mode: .normal)
                                                _ = await Legendary.command(args: ["launch", game.appName], useCache: false)
                                            }
                                        }) {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.green)
                                                .padding()
                                        }
                                        // .shadow(color: .green, radius: 10, x: 1, y: 1)
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
                                        // .shadow(color: .red, radius: 10, x: 1, y: 1)
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
                                            }

                                            Button(action: {
                                                Logger.app.warning("Stop install not implemented yet; execute \"killall cli\" lol")
                                            }) {
                                                Image(systemName: "stop.fill")
                                                    .foregroundStyle(.red)
                                                    .padding()
                                            }
                                            // .shadow(color: .red, radius: 10, x: 1, y: 1)
                                            .buttonStyle(.plain)
                                            .controlSize(.regular)

                                            .onChange(of: installing._finished) { _, newValue in
                                                if newValue == true {
                                                    isRefreshCalled = true
                                                }
                                            }

                                        } else {
                                            Button(action: {
                                                updateCurrentGame(game: game, mode: .optionalPacks)
                                                isInstallViewPresented = true
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
                Logger.app.info("Recieved refresh call for GameListView")
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
            }
        }
    }
}

#Preview {
    GameListView(isRefreshCalled: .constant(false))
}
