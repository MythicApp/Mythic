// where the hell is the comment

import Shimmer
import SwiftUI
import SwordRPC
import OSLog
import Darwin

// FIXME: refactor: warning ‼️ below code may need a cleanup
struct GameSettingsView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @Bindable private var operationManager: GameOperationManager = .shared

    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0

    @State private var movingError: Error?
    @State private var isMovingErrorAlertPresented: Bool = false
    @State private var isMovingFileImporterPresented: Bool = false

    @State private var typingArgument: String = .init()
    
    @State private var isImageEmpty: Bool = true
    
    @State private var isFileSectionExpanded: Bool = true
    @State private var isContainerSectionExpanded: Bool = true
    @State private var isGameSectionExpanded: Bool = true
    @State private var isThumbnailURLChangeSheetPresented: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    ZStack(alignment: .bottomLeading) {
                        HeroGameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.7)

                        HStack {
                            if isImageEmpty && game.isFallbackImageAvailable {
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
                        // MARK: - Options Section
                        Section("Options", isExpanded: $isGameSectionExpanded) {
                            HStack {
                                // MARK: Thumbnail URL Modifier
                                VStack(alignment: .leading) {
                                    Text("Thumbnail URL")
                                    Text(game.verticalImageURL?.host ?? "Unknown")
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
                                .disabled(game.storefront != .local)
                            }

                            // MARK: Launch Argument Modifier
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Launch Arguments")

                                    if !game.launchArguments.isEmpty {
                                        ScrollView(.horizontal) {
                                            HStack {
                                                ForEach(game.launchArguments, id: \.self) { argument in
                                                    ArgumentItem(game: $game, launchArguments: $game.launchArguments, argument: argument)
                                                }

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
                                    Button("", systemImage: "return") {
                                        submitLaunchArgument()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // MARK: File Integrity verification button
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Verify File Integrity")

                                    if let currentOperation = operationManager.queue.first,
                                       case .repair = currentOperation.type,
                                       currentOperation.game == game {
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(.linear)
                                        }

                                        Spacer()
                                    }
                                }

                                Spacer()

                                GameCard.Buttons.VerificationButton(game: $game, withLabel: true)
                            }
                        }

                        // MARK: - File section
                        Section("File", isExpanded: $isFileSectionExpanded) {
                            // MARK: Game location modifier
                            HStack {
                                Text("Move \"\(game.title)\"")

                                Spacer()

                                if operationManager.queue.contains(where: { $0.game == game && $0.type == .move }) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button("Move...") {
                                        isMovingFileImporterPresented = true
                                    }
                                    .disabled(operationManager.queue.first?.game == game)
                                    // FIXME: xcode's code formatter does NOT like using stacked parameters,
                                    // FIXME: it messes up the indent for the .alert below this
                                    .fileImporter(
                                        isPresented: $isMovingFileImporterPresented,
                                        allowedContentTypes: [.folder],
                                        allowsMultipleSelection: false
                                    ) { result in
                                        switch result {
                                        case .success(let success):
                                            guard let newLocation = success.first else { return }

                                            Task { @MainActor in
                                                do {
                                                    try await game.move(to: newLocation)
                                                } catch {
                                                    movingError = error
                                                    isMovingErrorAlertPresented = true
                                                }
                                            }
                                        case .failure(let failure):
                                            movingError = failure
                                            isMovingErrorAlertPresented = true
                                        }
                                    }
                                    .alert("Unable to move \"\(game.title)\".",
                                           isPresented: $isMovingErrorAlertPresented,
                                           presenting: movingError) { _ in
                                        if #available(macOS 26.0, *) {
                                            Button("OK", role: .close) {
                                                isPresented = false
                                            }
                                        } else {
                                            Button("OK", role: .cancel) {
                                                isPresented = false
                                            }
                                        }
                                    } message: { error in
                                        Text(error?.localizedDescription ?? "Unknown error.")
                                    }
                                }
                            }

                            // MARK: View location in Finder
                            if case .installed(let location, _) = game.installationState {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Location", comment: "Game Location")
                                        Text(location.prettyPath)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button("Show in Finder") {
                                        workspace.activateFileViewerSelecting([location])
                                    }
                                }
                            }
                        }

                        // MARK: - Container Settings Section
                        Section("Container Settings", isExpanded: $isContainerSectionExpanded) {
                            ContainerSettingsView(selectedContainerURL: $game.containerURL,
                                                  withPicker: true)
                        }
                        .disabled({
                            if case .installed(_, let platform) = game.installationState {
                                return platform != .windows
                            } else {
                                return true
                            }
                        }())
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
    func submitLaunchArgument() {
        let cleanedArgument = typingArgument
            .trimmingCharacters(in: .illegalCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // split parsed tokens from cleanedArgument
        var w = wordexp_t() // swiftlint:disable:this identifier_name
        defer { wordfree(&w) }

        // verify success through exit code
        guard Darwin.wordexp(cleanedArgument, &w, 0) == 0 else { return }

        let splitArguments: [String] = (0..<Int(w.we_wordc))
            .compactMap({ String(cString: w.we_wordv[$0]!) })

        if !cleanedArgument.isEmpty,
           !game.launchArguments.contains(typingArgument) {
            game.launchArguments += splitArguments
            typingArgument = .init()
        }
    }
}

private extension GameSettingsView {
    var bottomBar: some View {
        HStack {
            if case .installed(_, let platform) = game.installationState {
                SubscriptedTextView(platform.description)
            }
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
            presence.details = "Configuring \"\(game.title)\""
            presence.state = "Configuring \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
    }
}

extension GameSettingsView {
    struct ArgumentItem: View {
        @Binding var game: Game
        @Binding var launchArguments: [String]
        var argument: String
        
        @State var isHoveringOverArgument: Bool = false
        
        var body: some View {
            HStack {
                Text(argument)
                    .monospaced()
                    .foregroundStyle(isHoveringOverArgument ? .red : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .background(in: .capsule)
            .backgroundStyle(.quinary)
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
        @Binding var game: Game
        @Binding var isPresented: Bool

        @State private var isImageEmpty: Bool = true
        @State private var imageRefreshFlag: Bool = false
        
        func modifyThumbnailURL() {
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
                            GameCard.ImageURLModifierView(game: $game, imageURL: $game._verticalImageURL)
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
    GameSettingsView(game: .constant(placeholderGame(type: Game.self)), isPresented: .constant(true))
        .environmentObject(NetworkMonitor.shared)
}
