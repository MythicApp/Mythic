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
import Shimmer

extension GameCard {
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

                                    if !FileManager.default.fileExists(atPath: thumbnailDirectoryURL.path(percentEncoded: false)) {
                                        try FileManager.default.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                                    }

                                    let newThumbnailURL = thumbnailDirectoryURL.appendingPathComponent(UUID().uuidString)

                                    try FileManager.default.copyItem(at: url, to: newThumbnailURL)

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
