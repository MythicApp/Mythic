//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI
import Cocoa
import CachedAsyncImage

struct HomeView: View {
    
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
                        CachedAsyncImage(url: URL(string: "https://cdn1.epicgames.com/item/cbd5b3d310a54b12bf3fe8c41994174f/EGS_VALORANT_RiotGames_S2_1200x1600-a0ffbc8c70fd33180b6f1bdb1dfd4eb2")) { phase in
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
                                            Text("RECENTLY PLAYED")
                                                .font(.footnote)
                                                .foregroundStyle(.placeholder)
                                            
                                            Text("VALORANT")
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            
                                        }) {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.white)
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
                    Text("Ballsy Nuts")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(10)

                VStack {
                    Text("Sus")
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
