//
//  GameImageCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 1/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import Shimmer

// TODO: use this to unify specialised imagecards for each gamecard type
struct ImageCard: View {
    var url: URL?
    @Binding var isImageEmpty: Bool
    
    var withBlur: Bool = true
    @AppStorage("imageCardBlur") private var imageCardBlur: Double = 0.0
    
    var body: some View {
        if let url = url {
            GeometryReader { geometry in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
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
                                .onDisappear {
                                    withAnimation { isImageEmpty = true }
                                }
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                    case .failure:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
                    @unknown default:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
                    }
                }
                .frame(width: geometry.size.width,
                       height: geometry.size.height)
                .background(.quinary)
                .clipShape(.rect(cornerRadius: 20))
            }
        } else {
            ContentUnavailableView(
                "Image Unavailable",
                systemImage: "photo.badge.exclamationmark",
                description: .init("""
                    This game doesn't have an image that Mythic can display in this style.
                    """)
            )
        }
    }
}
