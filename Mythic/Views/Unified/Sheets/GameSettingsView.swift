// where the hell is the comment

import Shimmer
import SwiftUI
import SwordRPC
import OSLog

// FIXME: refactor: warning ‼️ below code may need a cleanup
struct GameSettingsView: View {
    @Binding var game: LegacyGame
    @Binding var isPresented: Bool
    
    @ObservedObject var operation: GameOperation = .shared
    
    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0
    
    @State private var selectedContainerURL: URL?
    @State private var moving: Bool = false
    @State private var movingError: Error?
    @State private var isMovingErrorPresented: Bool = false
    @State private var typingArgument: String = .init()
    @State private var launchArguments: [String] = .init()
    
    @State private var isImageEmpty: Bool = true
    
    @State private var isFileSectionExpanded: Bool = true
    @State private var isContainerSectionExpanded: Bool = true
    @State private var isGameSectionExpanded: Bool = true
    @State private var isThumbnailURLChangeSheetPresented: Bool = false
    
    init(game: Binding<LegacyGame>, isPresented: Binding<Bool>) {
        _game = game
        _isPresented = isPresented
        _selectedContainerURL = State(initialValue: game.wrappedValue.containerURL)
        _launchArguments = State(initialValue: game.launchArguments.wrappedValue)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    ZStack(alignment: .bottomLeading) {
                        HeroGameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.7)

                        HStack {
                            if isImageEmpty, game.isFallbackImageAvailable {
                                GameCard.FallbackImageCard(game: .constant(game))
                                    .frame(width: 65, height: 65)
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.trailing)
                            }

                            VStack(alignment: .leading) {
                                HStack {
                                    GameCard.TitleAndInformationView(game: $game, withSubscriptedInfo: false)
                                }
                                HStack {
                                    GameCard.ButtonsView(game: $game, withLabel: true)
                                        .clipShape(.capsule)
                                }
                            }
                        }
                        .padding([.leading, .bottom])
                        .conditionalTransform(if: !isImageEmpty) { view in
                            view
                                .foregroundStyle(.white)
                        }
                    }

                    Form {
                        Section("Options", isExpanded: $isGameSectionExpanded) {
                            thumbnailURLRow
                            launchArgumentsRow
                            verifyFileIntegrityRow
                        }

                        Section("File", isExpanded: $isFileSectionExpanded) {
                            moveGameRow
                            if let gameLocation = game.location {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Location", comment: "game context")
                                        Text(gameLocation.prettyPath)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button("Show in Finder") {
                                        workspace.activateFileViewerSelecting([gameLocation])
                                    }
                                }
                            }
                        }

                        Section("Container Settings", isExpanded: $isContainerSectionExpanded) {
                            if selectedContainerURL != nil {
                                ContainerSettingsView(selectedContainerURL: $selectedContainerURL, withPicker: true)
                            }
                        }
                        .disabled(game.platform != .windows)
                        .onChange(of: selectedContainerURL) { game.containerURL = $1 }
                    }
                    .formStyle(.grouped)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        
        bottomBar
    }
}

private extension GameSettingsView {
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
                ThumbnailURLChangeView(game: $game, isPresented: $isThumbnailURLChangeSheetPresented)
                    .padding()
                    .frame(minWidth: 750, idealHeight: 350)
            }
            .disabled(game.source != .local)
        }
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
                    // reduce performance overhead by only allowing animations for the first two characters
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
                    GameOperation.InstallArguments(game: game,
                                                   platform: game.platform,
                                                   type: .repair
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
                ProgressView(value: operation.status.progress?.percentage, total: 100.0)
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
}

private extension GameSettingsView {
    var moveGameRow: some View {
        HStack {
            Text("Move \"\(game.title)\"")
            
            Spacer()
            
            if !moving {
                Button("Move...") {
                    moveGame()
                }
                .disabled(GameOperation.shared.runningGameIDs.contains(game.id))
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
        openPanel.directoryURL = game.location

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
}

private extension GameSettingsView {
    var bottomBar: some View {
        HStack {
            SubscriptedTextView(game.platform.rawValue)
            GameCard.SubscriptedInfoView(game: $game)
            
            Spacer()
            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    func setDiscordPresence() {
        discordRPC.setPresence({
            var presence: RichPresence = .init()
            presence.details = "Configuring \(game.platform.rawValue) game \"\(game.title)\""
            presence.state = "Configuring \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
    }
}

extension GameSettingsView {
    struct ArgumentItem: View {
        @Binding var game: LegacyGame
        @Binding var launchArguments: [String]
        var argument: String
        
        @State var isHoveringOverArgument: Bool = false
        
        var body: some View {
            HStack {
                Text(argument)
                    .monospaced()
                    .foregroundStyle(isHoveringOverArgument ? .red : .secondary)
            }
            .padding(3)
            .background(in: .capsule)
            .onHover { hovering in
                withAnimation { isHoveringOverArgument = hovering }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    launchArguments.removeAll(where: { $0 == argument })
                    if launchArguments.isEmpty { // FIXME: for `.onChange` not firing when args become empty
                        game.launchArguments = .init()
                    }
                }
            }
        }
    }
    
    struct ThumbnailURLChangeView: View {
        @Binding var game: LegacyGame
        @Binding var isPresented: Bool
        
        @State private var newImageURLString: String = .init()
        @State private var isImageEmpty: Bool = true
        @State private var imageRefreshFlag: Bool = false
        
        func modifyThumbnailURL() {
            game.imageURL = URL(string: newImageURLString) ?? nil
            Task {
                await MainActor.run {
                    isPresented = false
                }
            }
        }
        
        var body: some View {
            HStack {
                GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                    .id(imageRefreshFlag)
                
                VStack {
                    Form {
                        VStack(alignment: .leading) {
                            GameCard.ImageURLModifierView(game: $game, imageURLString: $newImageURLString)
                                .onChange(of: newImageURLString, { imageRefreshFlag.toggle() })
                        }
                    }
                    .formStyle(.grouped)
                    
                    HStack {
                        Button("Close", action: { isPresented = false })
                        
                        Spacer()
                        
                        Button("Done", action: { modifyThumbnailURL() })
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

#Preview {
    GameSettingsView(game: .constant(placeholderGame(forSource: .local)), isPresented: .constant(true))
        .environmentObject(NetworkMonitor.shared)
}
