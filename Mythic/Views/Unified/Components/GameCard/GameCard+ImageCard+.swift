//
//  GameCard+ImageCard+.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import OSLog

extension GameCard {
    struct FallbackImageCard: View {
        @Binding var game: Game
        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0
        var withBlur: Bool = true

        var body: some View {
            if case .local = game.source {
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

                                    guard let appHome = Bundle.appHome else { return }
                                    let thumbnailDirectoryURL: URL = appHome.appending(path: "Thumbnails/Custom/\(game.source.rawValue)")

                                    do {
                                        if !files.fileExists(atPath: thumbnailDirectoryURL.path(percentEncoded: false)) {
                                            try files.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                                        }

                                        let newThumbnailURL = thumbnailDirectoryURL.appendingPathComponent(UUID().uuidString)

                                        try files.copyItem(at: url, to: newThumbnailURL)

                                        // game.path is not stateful, so i'll have to update it as a string to invoke UI updates
                                        imageURLString = newThumbnailURL.absoluteString
                                    } catch {
                                        Logger.app.error("Unable to import thumbnail: \(error.localizedDescription)")
                                        presentThumbnailImportError(error)
                                    }
                                case .failure(let failure):
                                    presentThumbnailImportError(failure)
                                }

                                @MainActor
                                func presentThumbnailImportError(_ error: Error) {
                                    thumbnailImportError = error
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

                    Button("Reset image to default") {
                        imageURLString = .init()
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
