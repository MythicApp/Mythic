import CachedAsyncImage
import SwiftUI

struct GameListRow: View { // TODO: will redo myself
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game: \(game.title)")
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
        .accessibilityHidden(true)
    }

    var gameInfo: some View {
        VStack(alignment: .leading) {
            Text(game.title)
                .font(.headline)
            Text(game.source.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Game: \(game.title), Type: \(game.source.rawValue)")
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
                .keyboardShortcut("p", modifiers: [.command])
                .help("Play \"\(game.title)\"")
                .disabled(!isGamePlayable)
            } else {
                Button {
                    isInstallSheetPresented = true
                } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .keyboardShortcut("i", modifiers: [.command])
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
        .keyboardShortcut("f", modifiers: [.command])
        .help(game.isFavourited ? "Remove from favorites" : "Add to favorites")
    }

    var settingsButton: some View {
        Button {
            isGameSettingsSheetPresented = true
        } label: {
            Image(systemName: "gear")
        }
        .keyboardShortcut(",", modifiers: [.command])
        .help("Modify settings for \"\(game.title)\"")
        .sheet(isPresented: $isGameSettingsSheetPresented) {
            GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
        }
    }

    var launchErrorAlert: Alert {
        Alert(
            title: Text("Error launching \"\(game.title)\"."),
            message: Text(launchError?.localizedDescription ?? "Unknown Error.")
        )
    }

    var isGameInstalled: Bool {
        game.source == .local || ((try? Legendary.getInstalledGames()) ?? .init()).contains(game)
    }

    var isGamePlayable: Bool {
        let gameExists = game.path != nil ? files.fileExists(atPath: game.path!) : false
        return gameExists && !operation.runningGames.contains(game) && !Wine.bottleURLs.isEmpty
    }

    func launchGame() {
        Task(priority: .userInitiated) {
            do {
                switch game.source {
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

    func toggleFavourite() {
        game.isFavourited.toggle()
        withAnimation { animateFavouriteIcon = game.isFavourited }
    }
}

#Preview {
    GameListRow(
        game: .constant(
            .init(
                source: .epic,
                title: "firtbite;",
                wideImageURL: .init(
                    string: "https://i.imgur.com/CZt2F4s.png"
                )
            )
        )
    )
    .environmentObject(NetworkMonitor())
}
