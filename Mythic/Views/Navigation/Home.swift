//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Cocoa
import CachedAsyncImage

// MARK: - HomeView Struct
/**
 The main view displaying the home screen of the Mythic app.
 */
struct HomeView: View {
    // MARK: - State Variables
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
    @State private var recentlyPlayedImageURL: String = .init()
    
    @State private var animateStar: Bool = false
    let animateStarTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect() // why on god's green earth is it so difficult on swift to repeat something every 2 seconds
    
    // MARK: - Variables
    private let recentlyPlayedGame: Legendary.Game? = try? PropertyListDecoder().decode(
        Legendary.Game.self,
        from: defaults.object(forKey: "recentlyPlayed") as? Data ?? Data()
    )
    
    // MARK: - Gradient
    /// The gradient used in the background.
    let gradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: .purple, location: 0),
            .init(color: .clear, location: 0.4)
        ]),
        startPoint: .bottom,
        endPoint: .top
    )
    
    // MARK: - Body
    var body: some View {
        HStack {
            // MARK: - Recent Game Display
            VStack {
                ZStack {
                    HStack {
                        // MARK: Image
                        AsyncImage(url: URL(string: recentlyPlayedImageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxHeight: .infinity)
                            case .success(let image):
                                ZStack {
                                    // MARK: Main Image
                                    image 
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxHeight: .infinity)
                                        .clipped()
                                        .overlay(
                                            // MARK: Blurred Overlay
                                            image
                                                .resizable()
                                                .blur(radius: 10, opaque: true)
                                                .mask(
                                                    LinearGradient(gradient: Gradient(stops: [
                                                        Gradient.Stop(color: Color(white: 0, opacity: 0),
                                                                      location: 0.65),
                                                        Gradient.Stop(color: Color(white: 0, opacity: 1),
                                                                      location: 0.8)
                                                    ]), startPoint: .top, endPoint: .bottom)
                                                )
                                        )
                                        .overlay(
                                            // MARK: Gradient Overlay (masked on blur)
                                            LinearGradient(gradient: Gradient(stops: [
                                                Gradient.Stop(color: Color(white: 0, opacity: 0),
                                                              location: 0.6),
                                                Gradient.Stop(color: Color(white: 0, opacity: 0.25),
                                                              location: 1)
                                            ]), startPoint: .top, endPoint: .bottom)
                                        )
                                }
                                .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "network.slash")
                                    .imageScale(.large)
                                    .frame(maxHeight: .infinity)
                            @unknown default:
                                Image(systemName: "exclamationmark.triangle")
                                    .imageScale(.large)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .onAppear {
                            Task(priority: .high) {
                                recentlyPlayedImageURL = await Legendary.getImage(
                                    of: recentlyPlayedGame ?? Legendary.placeholderGame,
                                    type: .tall
                                )
                            }
                        }
                        .cornerRadius(10)
                        .overlay(
                            ZStack(alignment: .bottom) {
                                VStack {
                                    Spacer()
                                    
                                    HStack {
                                        VStack {
                                            HStack {
                                                Text("RECENTLY PLAYED")
                                                    .font(.footnote)
                                                    .foregroundStyle(.placeholder)
                                                
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                // MARK: Game Title
                                                Text(recentlyPlayedGame?.title ?? "Unknown") // TODO: marquee effect
                                                    .font(.title)
                                                    .scaledToFit()
                                                
                                                Spacer()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            Task(priority: .userInitiated) {
                                                try? await Legendary.launch(
                                                    game: recentlyPlayedGame ?? Legendary.placeholderGame,
                                                    bottle: URL(filePath: Wine.defaultBottle.path)
                                                ) // FIXME: horrible programming; not threadsafe at all
                                            }
                                        } label: {
                                            Image(systemName: "play.fill")
                                                .padding()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.extraLarge)
                                    }
                                    .padding()
                                }
                            }
                        )
                    }
                }
            }
            .background(.background)
            .cornerRadius(10)
            
            // MARK: - Side Views
            VStack {
                // MARK: View 1 (Top)
                VStack {
                    Image(systemName: animateStar ? "star.fill" : "calendar.badge.clock")
                        .resizable()
                        .symbolRenderingMode(.palette)
                        .symbolEffect(.bounce, value: animateStar)
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(.yellow, .white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .onReceive(animateStarTimer) { _ in
                            animateStar.toggle()
                        }
                    
                    Text("Favourites (Not implemented yet)")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(10)
                
                // MARK: View 2 (Bottom)
                VStack {
                    NotImplementedView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
