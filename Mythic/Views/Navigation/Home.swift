//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Cocoa
import CachedAsyncImage

struct HomeView: View {
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
    let gradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: .purple, location: 0),
            .init(color: .clear, location: 0.4)
        ]),
        startPoint: .bottom,
        endPoint: .top
    )
    
    var body: some View {
        HStack {
            VStack {
                ZStack {
                    HStack {
                        CachedAsyncImage(url: URL(string: "https://cdn1.epicgames.com/item/9773aa1aa54f4f7b80e44bef04986cea/EGS_RocketLeague_PsyonixLLC_S2_1200x1600-ebcb79b7c8aa2432c3ce52dfd4fc4ae0")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                ZStack {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxHeight: .infinity)
                                        .clipped()
                                        .overlay(
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
                                                Text("Rocket League")
                                                    .font(.title)
                                                
                                                Spacer()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            
                                        } label: {
                                            Image(systemName: "play.fill")
                                            //  .foregroundStyle(.background)
                                                .padding()
                                        }
                                        // .shadow(color: .green, radius: 10, x: 1, y: 1)
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
            
            VStack {
                VStack {
                    NotImplementedView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(10)
                
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

#Preview {
    HomeView()
}
