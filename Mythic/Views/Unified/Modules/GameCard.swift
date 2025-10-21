//
//  GameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Shimmer
import SwiftyJSON
import Glur
import OSLog

struct GameCard: View {
    @Binding var game: Game
    @ObservedObject var viewModel: GameCardVM = .init()

    @State private var isImageEmpty: Bool = true
    @State private var isImageEmptyPreMacOSTahoe: Bool = true

    var body: some View {
        ImageCard(game: $game, isImageEmpty: $isImageEmpty)
            .overlay(alignment: .bottom) {
                gameOverlay
            }
    }

    @ViewBuilder
    var gameOverlay: some View {
        Group {
            HStack {
                VStack(alignment: .leading) {
                    GameCardVM.TitleAndInformationView(game: $game, font: .title3)
                }
                .layoutPriority(1)

                GameCardVM.ButtonsView(game: $game)
                    .clipShape(.capsule)
            }
            .padding(.horizontal)
            // conditionally change view foreground style for macOS <26
            .onChange(of: isImageEmpty) {
                if #unavailable(macOS 26.0) {
                    isImageEmptyPreMacOSTahoe = $1
                }
            }
            .conditionalTransform(if: !isImageEmptyPreMacOSTahoe) { view in
                view.foregroundStyle(.white)
            }
        }
        // use liquid glass on macOS 26+
        .customTransform { view in
            if #available(macOS 26.0, *) {
                view
                    .padding(.vertical)
                    .glassEffect(in: .rect(cornerRadius: 20.0))
                    .padding(4)
            } else {
                view
                    .padding(.bottom)
            }
        }
    }
}

/// ViewModifier that enables views to have a fade in effect.
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    opacity = 1
                }
            }
    }
}

extension GameCard {
    struct ImageCard: View {
        @Binding var game: Game

        /// Binding that updates when image is empty (default to true)
        @Binding var isImageEmpty: Bool

        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0

        var withBlur: Bool = true

        var body: some View {
            blankImageView
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    gameImage
                }
        }

        @ViewBuilder
        private var gameImage: some View {
            AsyncImage(url: game.imageURL) { phase in
                switch phase {
                case .empty:
                    FallbackImageCard(game: $game)
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }

                case .success(let image):
                    handleImage(image, withBlur, gameCardBlur)
                        .onAppear {
                            withAnimation { isImageEmpty = false }
                        }
                        .onDisappear {
                            withAnimation { isImageEmpty = true }
                        }
                case .failure(let error):
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init(error.localizedDescription)
                    )
                    .onAppear {
                        withAnimation { isImageEmpty = true }
                    }
                @unknown default:
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init("""
                        Please check your connection, and try again.
                        """)
                    )
                    .onAppear {
                        withAnimation { isImageEmpty = true }
                    }
                }
            }
            .grayscale({
                if let path = game.path,
                   !files.fileExists(atPath: path),
                   game.isInstalled {
                    return 1.0
                }

                return 0.0
            }())
        }

        /* private FIXME: what */ var handleImage: (Image, Bool, Double) -> AnyView = { image, withBlur, gameCardBlur in
            return AnyView(
                ZStack {
                    if withBlur && (gameCardBlur > 0) /* dirtyfix */ {
                        image
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fill)
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: gameCardBlur)
                    }

                    image
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                        .customTransform { view in
                            if #unavailable(macOS 26.0) {
                                view.glur(radius: 20, offset: 0.5, interpolation: 0.7)
                            } else {
                                view
                            }
                        }
                        .clipShape(.rect(cornerRadius: 20))
                        .modifier(FadeInModifier())
                }
            )
        }

        private var blankImageView: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quinary)
        }
    }

    struct FallbackImageCard: View {
        @Binding var game: Game
        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0
        var withBlur: Bool = true

        var body: some View {
            if case .local = game.source, game.imageURL == nil {
                let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))

                ZStack {
                    if withBlur && (gameCardBlur > 0) /* dirtyfix */ {
                        image
                            .resizable()
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: 20.0 /* gameCardBlur */)
                    }

                    image
                        .resizable()
                        .scaledToFit()
                        .modifier(FadeInModifier())
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.windowBackground)
                    .shimmering(
                        animation: .easeInOut(duration: 1)
                            .repeatForever(autoreverses: false),
                        bandSize: 1
                    )
            }
        }
    }

    struct ImageURLModifierView: View {
        @Binding var game: Game
        @Binding var imageURLString: String

        @State private var isThumbnailFileImporterPresented: Bool = false
        @State private var isThumbnailImportErrorPresented: Bool = false
        @State private var thumbnailImportError: Error?

        var body: some View {
            VStack(alignment: .leading) {
                TextField(text: $imageURLString, label: {
                    Text("Enter a thumbnail URL: (optional)")

                    HStack {
                        Text("Otherwise, browse for a thumbnail file: ")

                        Button("Browse...") {
                            isThumbnailFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isThumbnailFileImporterPresented,
                            allowedContentTypes: [
                                .png, .jpeg, .gif, .bmp, .ico, .tiff, .heic, .webP
                            ]) { result in
                                switch result {
                                case .success(let url):
                                    guard url.startAccessingSecurityScopedResource() else { return }
                                    defer { url.stopAccessingSecurityScopedResource() }

                                    let thumbnailDirectoryURL: URL = Bundle.appHome!.appending(path: "Thumbnails/Custom")

                                    do {
                                        if !files.fileExists(atPath: thumbnailDirectoryURL.path(percentEncoded: false)) {
                                            try files.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                                        }

                                        let newThumbnailURL = thumbnailDirectoryURL.appendingPathComponent(UUID().uuidString)

                                        try files.copyItem(at: url, to: newThumbnailURL)
                                        imageURLString = newThumbnailURL.absoluteString // game.path is not stateful, so i'll have to update it as a string
                                    } catch {
                                        Logger.app.error("Unable to import thumbnail: \(error.localizedDescription)")
                                        thumbnailImportError = error
                                        isThumbnailImportErrorPresented = true
                                    }
                                case .failure(let failure):
                                    thumbnailImportError = failure
                                    isThumbnailImportErrorPresented = true
                                }
                            }
                            .alert(isPresented: $isThumbnailImportErrorPresented) {
                                Alert(
                                    title: .init("Unable to import thumbnail."),
                                    message: .init(thumbnailImportError?.localizedDescription ?? "Unknown Error."),
                                    dismissButton: .default(Text("OK"))
                                )
                            }

                    }
                })
                .truncationMode(.tail)
                .onChange(of: imageURLString) {
                    game.imageURL = URL(string: $1)
                }
            }
        }
    }
}

#Preview {
    GameCard(game: .constant(.init(source: .epic, title: "MRAAAHH")))
        .environmentObject(NetworkMonitor.shared)
}
