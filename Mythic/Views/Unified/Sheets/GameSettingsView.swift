// where the hell is the comment

import Shimmer
import SwiftUI
import SwordRPC

struct GameSettingsView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @ObservedObject var operation: GameOperation = .shared

    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 5.0

    @State private var selectedContainerURL: URL?
    @State private var moving: Bool = false
    @State private var movingError: Error?
    @State private var isMovingErrorPresented: Bool = false
    @State private var typingArgument: String = .init()
    @State private var launchArguments: [String] = .init()

    @State private var isImageEmpty: Bool = true

    @State private var isFileSectionExpanded: Bool = true
    @State private var isWineSectionExpanded: Bool = true
    @State private var isGameSectionExpanded: Bool = true
    @State private var isThumbnailURLChangeSheetPresented: Bool = false

    init(game: Binding<Game>, isPresented: Binding<Bool>) {
        _game = game
        _isPresented = isPresented
        _selectedContainerURL = State(initialValue: game.wrappedValue.containerURL)
        _launchArguments = State(initialValue: game.launchArguments.wrappedValue)
    }

    var body: some View {
        HStack {
            VStack {
                Text(game.title)
                    .font(.title)

                GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
            }
            .padding(.trailing)

            Divider()

            Form {
                gameOptionsSection
                gameFileSection
                gameEngineSection
            }
            .formStyle(.grouped)
        }
        
        bottomBar
    }
}

private extension GameSettingsView {
    var gameOptionsSection: some View {
        Section("Options", isExpanded: $isGameSectionExpanded) {
            thumbnailURLRow
            launchArgumentsRow
            verifyFileIntegrityRow
        }
    }

    var thumbnailURLRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Thumbnail URL")
                Text(game.imageURL?.host ?? "Unknown")
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }

            Spacer()

            Button("Change...") {
                isThumbnailURLChangeSheetPresented = true
            }
            .sheet(isPresented: $isThumbnailURLChangeSheetPresented) {
                thumbnailURLChangeSheet
            }
            .disabled(game.source != .local)
        }
    }
    
    func modifyThumbnailURL() {
        if case .local = game.source {
            LocalGames.library?.remove(game)
            LocalGames.library?.insert(game)
            isThumbnailURLChangeSheetPresented = false
        }
    }

    var thumbnailURLChangeSheet: some View {
        HStack {
            TextField(
                "Enter New Thumbnail URL here...",
                text: Binding(
                    get: { game.imageURL?.absoluteString.removingPercentEncoding ?? .init()
                    },
                    set: {
                        game.imageURL = .init(string: $0)
                    }
                )
            )
            .truncationMode(.tail)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                modifyThumbnailURL()
            }
            
            Button("Done", action: { modifyThumbnailURL() })
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    var launchArgumentsRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Launch Arguments")

                if !launchArguments.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(launchArguments, id: \.self) { argument in
                                ArgumentItem(game: $game, launchArguments: $launchArguments, argument: argument)
                            }
                            .onChange(of: launchArguments, { game.launchArguments = $1 })

                            Spacer()
                        }
                    }
                    .scrollIndicators(.never)
                }
            }

            Spacer()

            TextField("", text: Binding(
                get: { typingArgument },
                set: { newValue in
                    if (0...1).contains(typingArgument.count) {
                        withAnimation {
                            typingArgument = newValue
                        }
                    } else {
                        typingArgument = newValue
                    }
                }
            ))
                .onSubmit(submitLaunchArgument)

            if !typingArgument.isEmpty {
                Button {
                    submitLaunchArgument()
                } label: {
                    Image(systemName: "return")
                }
                .buttonStyle(.plain)
            }
        }
    }

    func submitLaunchArgument() {
        let cleanedArgument = typingArgument
            .trimmingCharacters(in: .illegalCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let splitArguments = cleanedArgument
            .split(separator: .whitespace)
            .map({ String($0) })

        if !cleanedArgument.isEmpty,
           !launchArguments.contains(typingArgument) {
            game.launchArguments += splitArguments
            launchArguments = game.launchArguments

            typingArgument = .init()
        }
    }

    var verifyFileIntegrityRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Verify File Integrity")

                if operation.current?.game == game {
                    verificationProgressView
                }
            }

            Spacer()

            Button("Verify...") {
                operation.queue.append(
                    GameOperation.InstallArguments(
                        game: game, platform: game.platform!, type: .repair
                    )
                )
            }
            .disabled(game.source != .epic)
            .disabled(operation.queue.contains(where: { $0.game == game }))
            .disabled(operation.current?.game == game)
        }
    }

    var verificationProgressView: some View {
        HStack {
            if operation.status.progress != nil {
                ProgressView(value: operation.status.progress?.percentage)
                    .controlSize(.small)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .progressViewStyle(.linear)
            }
            Spacer()
        }
    }

    var gameFileSection: some View {
        Section("File", isExpanded: $isFileSectionExpanded) {
            moveGameRow
            gameLocationRow
        }
    }

    var moveGameRow: some View {
        HStack {
            Text("Move \"\(game.title)\"")

            Spacer()

            if !moving {
                Button("Move...") {
                    moveGame()
                }
                .disabled(GameOperation.shared.runningGames.contains(game))
                .alert(isPresented: $isMovingErrorPresented) {
                    Alert(
                        title: .init("Unable to move \"\(game.title)\"."),
                        message: .init(movingError?.localizedDescription ?? "Unknown Error.")
                    )
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    func moveGame() {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Move"
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.directoryURL = .init(filePath: game.path ?? .init())

        if case .OK = openPanel.runModal(), let newLocation = openPanel.urls.first {
            Task {
                do {
                    moving = true
                    try await game.move(to: newLocation)
                    moving = false
                } catch {
                    movingError = error
                    isMovingErrorPresented = true
                }
            }
        }
    }

    var gameLocationRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Game Location:")
                Text(URL(filePath: game.path ?? "Unknown").prettyPath())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Show in Finder") {
                workspace.activateFileViewerSelecting([URL(filePath: game.path!)])
            }
            .disabled(game.path == nil)
        }
    }

    var gameEngineSection: some View {
        Section("Engine (Wine)", isExpanded: $isWineSectionExpanded) {
            if selectedContainerURL != nil {
                ContainerSettingsView(selectedContainerURL: $selectedContainerURL, withPicker: true)
            }
        }
        .disabled(game.platform != .windows)
        .onChange(of: selectedContainerURL) { game.containerURL = $1 }
    }

    var bottomBar: some View {
        HStack {
            SubscriptedTextView(game.platform?.rawValue ?? "Unknown")
            SubscriptedTextView(game.source.rawValue)
            if (try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed")) == game {
                SubscriptedTextView("Recent")
            }
            Spacer()
            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
    }

    func setDiscordPresence() {
        discordRPC.setPresence({
            var presence: RichPresence = .init()
            presence.details = "Configuring \(game.platform?.rawValue ?? .init()) game \"\(game.title)\""
            presence.state = "Configuring \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
    }
}

struct ArgumentItem: View {
    @Binding var game: Game
    @Binding var launchArguments: [String]
    var argument: String

    @State var isHoveringOverArgument: Bool = false

    var body: some View {
        HStack {
            if isHoveringOverArgument {
                Image(systemName: "xmark.bin")
                    .imageScale(.small)
            }

            Text(argument)
                .monospaced()
                .foregroundStyle(isHoveringOverArgument ? .red : .secondary)
        }
        .padding(3)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 7)
                .foregroundStyle(.tertiary)
                .shadow(radius: 5)
        })
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHoveringOverArgument = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                launchArguments.removeAll(where: { $0 == argument })
                if launchArguments.isEmpty { // fix for `.onChange` not firing when args become empty
                    game.launchArguments = .init()
                }
            }
        }
    }
}

#Preview {
    GameSettingsView(game: .constant(.init(source: .epic, title: .init())), isPresented: .constant(true))
}
