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
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var notImplementedAlert = false
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
                        CachedAsyncImage(url: URL(string: "https://cdn1.epicgames.com/item/fn/26BR_C4S4_EGS_Launcher_Blade_1200x1600_1200x1600-72d477839e2f1e1a9b3847d0998f50bc")) { phase in
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
                                            Text("RECENTLY PLAYED")
                                                .frame(alignment: .leading)
                                                .font(.footnote)
                                                .foregroundStyle(.placeholder)

                                            Text("Fortnite")
                                                .font(.title)
                                                .frame(alignment: .leading)
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
                    HStack {
                        if isAppInstalled(bundleIdentifier: "com.isaacmarovitz.Whisky") {
                            Circle()
                                .foregroundColor(.green)
                                .frame(width: 10, height: 10)
                                .shadow(color: .green, radius: 10, x: 1, y: 1)
                            Text("Whisky installed!")
                        } else {
                            Circle()
                                .foregroundColor(.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red, radius: 10, x: 1, y: 1)
                            Text("Whisky is not installed!")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .cornerRadius(10)

                VStack {
                    WebView(
                        loadingError: $loadingError,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        isLoading: $isLoading,
                        urlString: urlString
                    )
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
