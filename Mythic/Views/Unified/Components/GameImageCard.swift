//
//  GameImageCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 1/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import Shimmer

struct GameImageCard: View {
    var game: Game?
    var url: URL?
    @Binding var isImageEmpty: Bool
    
    var withBlur: Bool
    @AppStorage("gameImageCardBlur") private var imageCardBlur: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// - Note: `game` must be passed as a parameter in order to include fallback image URLs.
    init(game: Game? = nil, url: URL?, isImageEmpty: Binding<Bool>, withBlur: Bool = true) {
        self.game = game
        self.url = url
        self._isImageEmpty = isImageEmpty
        self.withBlur = withBlur
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .foregroundStyle(.quinary)
                            // a perpetually moving highlight is unnecessary motion; show a static placeholder instead
                            .conditionalTransform(if: !reduceMotion) { view in
                                view.shimmering(
                                    animation: .easeInOut(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    bandSize: 1
                                )
                            }
                    case .success(let image):
                        ZStack {
                            // blurred image as background
                            // save resources by only create this image if it'll be used for blur
                            if withBlur && (imageCardBlur > 0) {
                                // save resources by decreasing resolution scale of blurred image
                                let renderer: ImageRenderer = {
                                    let renderer = ImageRenderer(content: image)
                                    renderer.scale = 0.2
                                    return renderer
                                }()
                                
                                if let image = renderer.cgImage {
                                    Image(image, scale: 1, label: .init(""))
                                        .resizable()
                                        .blur(radius: imageCardBlur)
                                }
                            }
                            
                            image
                                .resizable()
                                .modifier(FadeInModifier())
                                .onAppear {
                                    withAnimation { isImageEmpty = false }
                                }
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                    case .failure(let error):
                        // cards are frequently too small to fit an explanation; keep it in the tooltip
                        UnavailableImagePlaceholder()
                            .help(Text("Unable to load the image. \(error.localizedDescription)"))
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    @unknown default:
                        UnavailableImagePlaceholder()
                            .help(Text("Unable to load the image."))
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    }
                }
                .frame(width: geometry.size.width,
                       height: geometry.size.height)
            } else if let game, game.isFallbackImageAvailable {
                GameImageCard.FallbackGameImageCard(game: .constant(game), withBlur: withBlur)
                    .padding()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
            } else {
                UnavailableImagePlaceholder()
                    .help(Text("This game doesn't have an image that Mythic can display in this style."))
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
            }
        }
        .background(.quinary)
        .clipShape(.rect(cornerRadius: 20))
        // artwork is decorative; the views that host it describe the game in text.
        .accessibilityHidden(true)
    }
}

extension GameImageCard {
    /// Compact stand-in for artwork that's missing, or failed to load.
    struct UnavailableImagePlaceholder: View {
        var body: some View {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A gradient placed between artwork and the text drawn over it,
/// keeping that text legible regardless of the image's contents.
struct ReadabilityScrim: View {
    var startPoint: UnitPoint = .top
    var endPoint: UnitPoint = .bottom

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var strength: Double {
        (colorSchemeContrast == .increased || reduceTransparency) ? 0.85 : 0.6
    }

    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0), .black.opacity(strength)],
            startPoint: startPoint,
            endPoint: endPoint
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension GameImageCard {
    // TODO: implement for windows .exes by implementing PEFile
    struct FallbackGameImageCard: View {
        @Binding var game: Game
        @AppStorage("gameImageCardBlur") private var imageCardBlur: Double = 0.0
        var withBlur: Bool = true
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        
        var body: some View {
            if case .installed(let location, _) = game.installationState {
                
                let image = Image(nsImage: NSWorkspace.shared.icon(forFile: location.path))
                
                ZStack {
                    // blurred image as background
                    // save resources by only create this image if it'll be used for blur
                    if withBlur && (imageCardBlur > 0) {
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
                                .blur(radius: imageCardBlur)
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
                    .conditionalTransform(if: !reduceMotion) { view in
                        view.shimmering(
                            animation: .easeInOut(duration: 1)
                                .repeatForever(autoreverses: false),
                            bandSize: 1
                        )
                    }
            }
        }
    }
}

#Preview {
    HStack {
        GameImageCard(game: placeholderGame(type: LocalGame.self) as Game,
                      url: placeholderGame(type: LocalGame.self).horizontalImageURL,
                      isImageEmpty: .constant(false),
                      withBlur: true)
        .aspectRatio(16/9, contentMode: .fill)
        
        GameImageCard(game: placeholderGame(type: Game.self),
                      url: placeholderGame(type: Game.self).verticalImageURL,
                      isImageEmpty: .constant(false),
                      withBlur: true)
        .aspectRatio(3/4, contentMode: .fill)
    }
    .aspectRatio(contentMode: .fit)
    .padding()
}
