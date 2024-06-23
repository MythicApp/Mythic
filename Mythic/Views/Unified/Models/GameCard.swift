import CachedAsyncImage
import Glur
import OSLog
import Shimmer
import SwiftUI
import SwiftyJSON

struct GameCard: View {
    @Binding var game: Game
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject var variables: VariableManager = .shared
    @ObservedObject var operation: GameOperation = .shared
    @AppStorage("minimiseOnGameLaunch") var minimizeOnGameLaunch: Bool = false

    @State private var isGameSettingsSheetPresented: Bool = false
    @State private var isUninstallSheetPresented: Bool = false
    @State private var isInstallSheetPresented: Bool = false
    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isLaunchErrorAlertPresented: Bool = false
    @State private var launchError: Error?
    @State private var hoveringOverDestructiveButton: Bool = false
    @State private var animateFavouriteIcon: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                gameImage
                    .overlay(alignment: .bottom) {
                        VStack {
                            gameTitleStack
                            buttonStack
                        }
                    }
            }
    }
}

private extension GameCard {

    var gameImage: some View {
        CachedAsyncImage(url: game.imageURL) { phase in
            switch phase {
            case .empty:
                emptyImagePlaceholder
            case .success(let image):
                loadedImage(image)
            case .failure, _:
                fallbackImagePlaceholder
            }
        }
    }

    var emptyImagePlaceholder: some View {
        Group {
            if case .local = game.type, game.imageURL == nil {
                localGameIcon
            } else {
                shimmeringPlaceholder
            }
        }
    }

    var localGameIcon: some View {
        let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))
        return ZStack {
            image
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .blur(radius: 20.0)

            image
                .resizable()
                .scaledToFit()
                .modifier(FadeInModifier())
        }
    }

    var shimmeringPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.windowBackground)
            .shimmering(
                animation: .easeInOut(duration: 1)
                    .repeatForever(autoreverses: false),
                bandSize: 1
            )
    }

    func loadedImage(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(.rect(cornerRadius: 20))
                .blur(radius: 20.0)

            image
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .glur(radius: 20, offset: 0.5, interpolation: 0.7)
                .clipShape(.rect(cornerRadius: 20))
                .modifier(FadeInModifier())
        }
    }

    var fallbackImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.windowBackground)
    }

    var gameTitleStack: some View {
        HStack {
            Text(game.title)
                .font(.bold(.title3)())

            SubscriptedTextView(game.type.rawValue)

            if isRecentlyPlayed {
                SubscriptedTextView("Recent")
            }

            Spacer()
        }
        .padding(.leading)
        .foregroundStyle(.white)
    }

    var isRecentlyPlayed: Bool {
        if let recent = try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed"),
            recent == game
        {
            return true
        }
        return false
    }

    var buttonStack: some View {
        HStack {
            if operation.current?.game.id == game.id {
                GameInstallProgressView()
                    .padding(.horizontal)
            } else if isGameInstalled {
                installedGameButtons
            } else {
                installButton
            }
        }
        .padding(.bottom)
    }

    var isGameInstalled: Bool {
        game.type == .local || ((try? Legendary.getInstalledGames()) ?? .init()).contains(game)
    }

    var installedGameButtons: some View {
        Group {
            engineInstallButton
            verifyButton
            playButton
            updateButton
            settingsButton
            favouriteButton
            deleteButton
        }
    }

    var engineInstallButton: some View {
        Group {
            if case .windows = game.platform, !Engine.exists {
                Button {
                    let app = MythicApp()
                    app.onboardingPhase = .engineDisclaimer
                    app.isOnboardingPresented = true
                } label: {
                    Image(systemName: "arrow.down.circle.dotted")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isConnected)
                .help("Install Mythic Engine")
            }
        }
    }

    var verifyButton: some View {
        Group {
            if case .epic = game.type,
                let json = try? JSON(
                    data: Data(contentsOf: URL(filePath: "\(Legendary.configLocation)/installed.json"))
                ),
                let needsVerification = json[game.id]["needs_verification"].bool, needsVerification
            {
                Button {
                    Task(priority: .userInitiated) {
                        operation.queue.append(
                            GameOperation.InstallArguments(
                                game: game, platform: game.platform!, type: .repair
                            )
                        )
                    }
                } label: {
                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isEpicAccessible)
                .help("Game verification is required for \"\(game.title)\".")
            }
        }
    }

    var playButton: some View {
        Group {
            if operation.launching == game {
                ProgressView()
                    .controlSize(.small)
                    .padding(5)
                    .clipShape(.circle)
            } else {
                Button {
                    launchGame()
                } label: {
                    Image(systemName: "play")
                        .padding(5)
                }
                .clipShape(.circle)
                .help(
                    game.path != nil
                        ? "Play \"\(game.title)\""
                        : "Unable to locate \(game.title) at its specified path (\(game.path ?? "Unknown"))"
                )
                .disabled(game.path != nil ? !files.fileExists(atPath: game.path!) : false)
                .disabled(operation.runningGames.contains(game))
                .disabled(Wine.bottleURLs.isEmpty)
                .alert(isPresented: $isLaunchErrorAlertPresented) {
                    Alert(
                        title: .init("Error launching \"\(game.title)\"."),
                        message: .init(launchError?.localizedDescription ?? "Unknown Error.")
                    )
                }
            }
        }
    }

    func launchGame() {
        Task(priority: .userInitiated) {
            do {
                switch game.type {
                case .epic:
                    try await Legendary.launch(game: game)
                case .local:
                    try await LocalGames.launch(game: game)
                }

                if minimizeOnGameLaunch { NSApp.windows.first?.miniaturize(nil) }
            } catch {
                launchError = error
                isLaunchErrorAlertPresented = true
            }
        }
    }

    var updateButton: some View {
        Group {
            if case .epic = game.type, Legendary.needsUpdate(game: game) {
                Button {
                    Task(priority: .userInitiated) {
                        operation.queue.append(
                            GameOperation.InstallArguments(
                                game: game, platform: game.platform!, type: .update
                            )
                        )
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isEpicAccessible)
                .disabled(operation.runningGames.contains(game))
                .help("Update \"\(game.title)\"")
            }
        }
    }

    var settingsButton: some View {
        Button {
            isGameSettingsSheetPresented = true
        } label: {
            Image(systemName: "gear")
                .padding(5)
        }
        .clipShape(.circle)
        .sheet(isPresented: $isGameSettingsSheetPresented) {
            GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
                .padding()
                .frame(minWidth: 750)
        }
        .help("Modify settings for \"\(game.title)\"")
    }

    var favouriteButton: some View {
        Button {
            game.isFavourited.toggle()
            withAnimation { animateFavouriteIcon = game.isFavourited }
        } label: {
            Image(systemName: animateFavouriteIcon ? "star.fill" : "star")
                .padding(5)
        }
        .clipShape(.circle)
        .help("Favourite \"\(game.title)\"")
        .shadow(color: .secondary, radius: animateFavouriteIcon ? 20 : 0)
        .symbolEffect(.bounce, value: animateFavouriteIcon)
        .task { animateFavouriteIcon = game.isFavourited }
    }

    var deleteButton: some View {
        Button {
            isUninstallSheetPresented = true
        } label: {
            Image(systemName: "xmark.bin")
                .padding(5)
                .foregroundStyle(hoveringOverDestructiveButton ? .red : .secondary)
        }
        .clipShape(.circle)
        .disabled(operation.current?.game != nil)
        .disabled(operation.runningGames.contains(game))
        .help("Delete \"\(game.title)\"")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { hoveringOverDestructiveButton = hovering }
        }
        .sheet(isPresented: $isUninstallSheetPresented) {
            UninstallViewEvo(game: $game, isPresented: $isUninstallSheetPresented)
                .padding()
        }
    }

    var installButton: some View {
        Button {
            isInstallSheetPresented = true
        } label: {
            Image(systemName: "arrow.down.to.line")
                .padding(5)
        }
        .clipShape(.circle)
        .disabled(!networkMonitor.isEpicAccessible)
        .disabled(operation.queue.contains(where: { $0.game == game }))
        .help("Download \"\(game.title)\"")
        .sheet(isPresented: $isInstallSheetPresented) {
            InstallViewEvo(game: $game, isPresented: $isInstallSheetPresented)
                .padding()
        }
    }
}

#Preview {
    GameCard(game: .constant(.init(type: .local, title: .init())))
        .environmentObject(NetworkMonitor())
}
