//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Cocoa
import CachedAsyncImage

// MARK: - HomeView Struct
/**
 The main view displaying the home screen of the Mythic app.
 */
struct HomeView: View {
    // MARK: - State Variables
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
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
                        AsyncImage(url: URL(string: UserDefaults.standard.object(forKey: "recentGame") as? String ?? "")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
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
                            @unknown default:
                                Image(systemName: "exclamationmark.triangle")
                                    .imageScale(.large)
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
                                                Text("Rocket League")
                                                    .font(.title)
                                                
                                                Spacer()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            // TODO: - Handle Play Button
                                        } label: {
                                            // MARK: Play Button
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
                    NotImplementedView()
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
