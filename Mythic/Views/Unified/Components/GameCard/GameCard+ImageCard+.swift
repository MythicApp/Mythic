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
            if case .installed(let location, _) = game.installationState {

                let image = Image(nsImage: workspace.icon(forFile: location.path))

                ZStack {
                    // blurred image as background
                    // save resources by only create this image if it'll be used for blur
                    if withBlur && (gameCardBlur > 0) {
                        // save resources by decreasing resolution scale of blurred image
                        let renderer: ImageRenderer = {
                            let renderer = ImageRenderer(content: image)
                            renderer.scale = 0.2
                            return renderer
                        }()

                        if let image = renderer.cgImage {
                            Image(image, scale: 1, label: .init(""))
                                .resizable()
                                .clipShape(.rect(cornerRadius: 20))
                                .blur(radius: 20.0 /* gameCardBlur */)
                        }
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
        @Binding var imageURL: URL?

        @State private var isThumbnailFileImporterPresented: Bool = false
        @State private var isThumbnailImportErrorPresented: Bool = false
        @State private var thumbnailImportError: Error?

        var body: some View {
            VStack(alignment: .leading) {
                TextField(text: .init(
                    get: { imageURL?.path ?? .init() },
                    set: { imageURL = .init(string: $0) }
                )) {
                    Text("Thumbnail URL")
                    Text("(optional)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Otherwise, browse for a thumbnail file: ")

                        Button("Browse...") {
                            isThumbnailFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isThumbnailFileImporterPresented,
                            allowedContentTypes: [.png, .jpeg, .gif, .bmp, .ico, .tiff, .heic, .webP]
                        ) { result in
                            switch result {
                            case .success(let url):
                                guard url.startAccessingSecurityScopedResource() else { return }
                                defer { url.stopAccessingSecurityScopedResource() }

                                guard let appHome = Bundle.appHome else { return }

                                do {
                                    guard let storefront = game.storefront else { throw CocoaError(.coderInvalidValue) }
                                    let thumbnailDirectoryURL: URL = appHome.appending(path: "Thumbnails/Custom/\(storefront.description)")

                                    if !files.fileExists(atPath: thumbnailDirectoryURL.path(percentEncoded: false)) {
                                        try files.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                                    }

                                    let newThumbnailURL = thumbnailDirectoryURL.appendingPathComponent(UUID().uuidString)

                                    try files.copyItem(at: url, to: newThumbnailURL)

                                    imageURL = newThumbnailURL
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
                        imageURL = nil
                    }
                }
                .truncationMode(.tail)
                .onChange(of: imageURL) {
                    game._verticalImageURL = $1
                }
            }
        }
    }
}
