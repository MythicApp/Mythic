import CachedAsyncImage
import SwiftUI

struct GameListRow: View {
    @Binding var game: Game
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject private var operation: GameOperation = .shared

    @State private var isGameSettingsSheetPresented: Bool = false
    @State private var isUninstallSheetPresented: Bool = false
    @State private var isInstallSheetPresented: Bool = false
    @State private var animateFavouriteIcon: Bool = false

    @AppStorage("minimiseOnGameLaunch") private var minimizeOnGameLaunch: Bool = false
    @State private var isLaunchErrorAlertPresented: Bool = false
    @State private var launchError: Error?

    var body: some View {
        HStack {
            gameImage
            gameInfo
            Spacer()
            actionButtons
        }
        .padding(.vertical, 5)
        .alert(isPresented: $isLaunchErrorAlertPresented) {
            launchErrorAlert
        }
    }
}

private extension GameListRow {

    var gameImage: some View {
        CachedAsyncImage(url: game.imageURL) { image in
            image.resizable().aspectRatio(contentMode: .fit)
        } placeholder: {
            Color.gray
        }
        .frame(width: 60, height: 60)
        .cornerRadius(8)
    }

    var gameInfo: some View {
        VStack(alignment: .leading) {
            Text(game.title)
                .font(.headline)
            Text(game.type.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    var actionButtons: some View {
        HStack(spacing: 10) {
            playOrInstallButton
            favouriteButton
            settingsButton
        }
    }

    var playOrInstallButton: some View {
        Group {
            if isGameInstalled {
                Button(action: launchGame) {
                    Image(systemName: "play")
                }
                .help("Play \"\(game.title)\"")
                .disabled(!isGamePlayable)
            } else {
                Button(action: { isInstallSheetPresented = true }) {
                    Image(systemName: "arrow.down.to.line")
                }
                .help("Download \"\(game.title)\"")
                .sheet(isPresented: $isInstallSheetPresented) {
                    InstallViewEvo(game: $game, isPresented: $isInstallSheetPresented)
                }
            }
        }
    }

    var favouriteButton: some View {
        Button(action: toggleFavourite) {
            Image(systemName: game.isFavourited ? "star.fill" : "star")
        }
        .help("Favourite \"\(game.title)\"")
    }

    var settingsButton: some View {
        Button(action: { isGameSettingsSheetPresented = true }) {
            Image(systemName: "gear")
        }
        .sheet(isPresented: $isGameSettingsSheetPresented) {
            GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
        }
        .help("Modify settings for \"\(game.title)\"")
    }

    var launchErrorAlert: Alert {
        Alert(
            title: Text("Error launching \"\(game.title)\"."),
            message: Text(launchError?.localizedDescription ?? "Unknown Error.")
        )
    }

    var isGameInstalled: Bool {
        game.type == .local || ((try? Legendary.getInstalledGames()) ?? .init()).contains(game)
    }

    var isGamePlayable: Bool {
        let gameExists = game.path != nil ? files.fileExists(atPath: game.path!) : false
        return gameExists && !operation.runningGames.contains(game) && !Wine.bottleURLs.isEmpty
    }

    func launchGame() {
        Task(priority: .userInitiated) {
            do {
                switch game.type {
                case .epic:
                    try await Legendary.launch(game: game, online: networkMonitor.isEpicAccessible)
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

    func toggleFavourite() {
        game.isFavourited.toggle()
        withAnimation { animateFavouriteIcon = game.isFavourited }
    }
}

#Preview {
    GameListRow(
        game: .constant(
            .init(
                type: .epic,
                title: "firtbite;",
                wideImageURL: .init(
                    string: "https://i.imgur.com/CZt2F4s.png"
                )
            )
        )
    )
    .environmentObject(NetworkMonitor())
}
