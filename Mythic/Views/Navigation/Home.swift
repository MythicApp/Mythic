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
    enum ActiveAlert {
        case launchError
    }
    
    struct LaunchError {
        static var message: String = .init()
        static var game: Legendary.Game? = nil // swiftlint:disable:this redundant_optional_initialization
    }
    
    // MARK: - State Variables
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
    @State private var recentlyPlayedImageURL: String = .init()
    
    @State private var isAlertPresented: Bool = false
    @State private var activeAlert: ActiveAlert = .launchError
    
    @State private var animateStar: Bool = false
    let animateStarTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect() // why on god's green earth is it so difficult on swift to repeat something every 2 seconds
    
    // MARK: - Variables
    private let recentlyPlayedGame: Legendary.Game? = try? PropertyListDecoder().decode(
        Legendary.Game.self,
        from: defaults.object(forKey: "recentlyPlayed") as? Data ?? Data()
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
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(3/4, contentMode: .fit)
                            case .success(let image):
                                ZStack {
                                    // MARK: Main Image
                                    image 
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fill)
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
                                    .symbolEffect(.appear)
                                    .imageScale(.large)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(3/4, contentMode: .fit)
                            @unknown default:
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolEffect(.appear)
                                    .imageScale(.large)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(3/4, contentMode: .fit)
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
                        .cornerRadius(20)
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
                                        
                                        if variables.getVariable("launching_\(recentlyPlayedGame?.appName ?? .init())") != true {
                                            Button {
                                                Task(priority: .userInitiated) {
                                                    do {
                                                        try await Legendary.launch(
                                                            game: recentlyPlayedGame ?? Legendary.placeholderGame,
                                                            bottle: URL(filePath: Wine.defaultBottle.path) // FIXME: add support for not just default wine bottle, use appstorage var that defaults to defaultbottle
                                                        )
                                                    } catch {
                                                        LaunchError.game = recentlyPlayedGame
                                                        LaunchError.message = "\(error)"
                                                        activeAlert = .launchError
                                                        isAlertPresented = true
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "play.fill")
                                                    .padding()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.extraLarge)
                                        } else {
                                            ProgressView()
                                                .padding()
                                        }
                                    }
                                    .padding()
                                }
                            }
                        )
                    }
                }
            }
            .background(.background)
            .cornerRadius(20)
            
            // MARK: - Side Views
            VStack {
                // MARK: View 1 (Top)
                VStack {
                    Image(systemName: animateStar ? "star.fill" : "calendar.badge.clock")
                        .resizable()
                        .symbolRenderingMode(.palette)
                        .symbolEffect(.bounce, value: animateStar)
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(animateStar ? .yellow : .yellow, .white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .onReceive(animateStarTimer) { _ in
                            animateStar.toggle()
                        }
                    
                    Text("Favourites (Not implemented yet)")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(20)
                
                // MARK: View 2 (Bottom)
                VStack {
                    NotImplementedView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(20)
            }
        }
        .padding()
        .alert(isPresented: $isAlertPresented) { // TODO: Note, add progressview for homeview play button
            switch activeAlert {
            case .launchError:
                Alert(
                    title: Text("Error launching \(LaunchError.game?.title ?? "game")."),
                    message: Text(LaunchError.message)
                )
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
