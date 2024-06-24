import CachedAsyncImage
import Shimmer
import SwiftUI
import SwordRPC

struct GameSettingsView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @StateObject var operation: GameOperation = .shared
    @State private var selectedBottleURL: URL?
    @State private var moving: Bool = false
    @State private var movingError: Error?
    @State private var isMovingErrorPresented: Bool = false
    @State private var typingArgument: String = .init()
    @State private var launchArguments: [String] = .init()
    @State private var isHoveringOverArg: Bool = false
    @State private var isFileSectionExpanded: Bool = true
    @State private var isWineSectionExpanded: Bool = true
    @State private var isGameSectionExpanded: Bool = true
    @State private var isThumbnailURLChangeSheetPresented: Bool = false

    init(game: Binding<Game>, isPresented: Binding<Bool>) {
        _game = game
        _isPresented = isPresented
        _selectedBottleURL = State(initialValue: game.wrappedValue.bottleURL)
        _launchArguments = State(initialValue: game.launchArguments.wrappedValue)
    }

    var body: some View {
        HStack {
            gameThumbnailSection
            Divider()
            gameSettingsForm
        }
        .overlay(alignment: .bottom) {
            bottomBar
        }
        .task(priority: .background) {
            setDiscordPresence()
        }
    }
}

private extension GameSettingsView {

    var gameThumbnailSection: some View {
        VStack {
            Text(game.title)
                .font(.title)

            gameThumbnail
        }
        .padding(.trailing)
    }

    var gameThumbnail: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                CachedAsyncImage(url: game.imageURL) { phase in
                    switch phase {
                    case .empty:
                        emptyThumbnailPlaceholder
                    case .success(let image):
                        loadedThumbnail(image)
                    case .failure:
                        failureThumbnailPlaceholder
                    @unknown default:
                        unknownThumbnailPlaceholder
                    }
                }
            }
    }

    var emptyThumbnailPlaceholder: some View {
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

    func loadedThumbnail(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(.rect(cornerRadius: 20))
                .blur(radius: 10.0)

            image
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(.rect(cornerRadius: 20))
                .modifier(FadeInModifier())
        }
    }

    var failureThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.windowBackground)
            .overlay {
                Image(systemName: "exclamationmark.triangle.fill")
            }
    }

    var unknownThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.windowBackground)
            .overlay {
                Image(systemName: "questionmark.circle.fill")
            }
    }

    var gameSettingsForm: some View {
        Form {
            gameOptionsSection
            gameFileSection
            gameEngineSection
        }
        .formStyle(.grouped)
    }

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
            .disabled(game.type != .local)
        }
    }

    var thumbnailURLChangeSheet: some View {
        TextField(
            "Enter New Thumbnail URL here...",
            text: Binding(
                get: { game.imageURL?.absoluteString.removingPercentEncoding ?? .init() },
                set: { game.imageURL = .init(string: $0) }
            )
        )
        .truncationMode(.tail)
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
                                ArgumentItem(launchArguments: $launchArguments, argument: argument)
                            }
                            .onChange(of: launchArguments, { game.launchArguments = $1 })

                            Spacer()
                        }
                    }
                    .scrollIndicators(.never)
                }
            }

            Spacer()
            TextField("", text: $typingArgument)
                .onSubmit(submitLaunchArgument)
        }
    }

    func submitLaunchArgument() {
        if !typingArgument.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            launchArguments.append(typingArgument)
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
            if selectedBottleURL != nil {
                BottleSettingsView(selectedBottleURL: $selectedBottleURL, withPicker: true)
            }
        }
        .disabled(game.platform != .windows)
        .disabled(!Engine.exists)
        .onChange(of: selectedBottleURL) { game.bottleURL = $1 }
    }

    var bottomBar: some View {
        HStack {
            SubscriptedTextView(game.platform?.rawValue ?? "Unknown")
            SubscriptedTextView(game.type.rawValue)
            if (try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed")) == game {
                SubscriptedTextView("Recent")
            }
            Spacer()
            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
    }

    func setDiscordPresence() {
        discordRPC.setPresence(
            {
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
    @Binding var launchArguments: [String]
    var argument: String

    @State var isHoveringOverArg: Bool = false

    var body: some View {
        HStack {
            if isHoveringOverArg {
                Image(systemName: "xmark.bin")
                    .imageScale(.small)
            }

            Text(argument)
                .monospaced()
                .foregroundStyle(isHoveringOverArg ? .red : .secondary)
        }
        .padding(3)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 7)
                .foregroundStyle(.tertiary)
                .shadow(radius: 5)
        })
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHoveringOverArg = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                launchArguments.removeAll(where: { $0 == argument })
            }
        }
    }
}

#Preview {
    GameSettingsView(game: .constant(.init(type: .epic, title: .init())), isPresented: .constant(true))
}
