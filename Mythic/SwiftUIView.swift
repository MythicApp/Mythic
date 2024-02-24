//
//  SwiftUIView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 20/2/2024.
//

import SwiftUI
import CachedAsyncImage
import Glur

struct SwiftUIView: View {
    @State private var game: Game = placeholderGame(.local)
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    var body: some View {
        CachedAsyncImage(
            url: URL(string: "https://cdn1.epicgames.com/spt-assets/9d5ee69e2cb2435981109ff152ad7694/phantom-galaxies-18xww.png"),
            urlCache: gameImageURLCache
        ) { phase in
            switch phase {
            case .empty:
                if !Legendary.getImage(of: game, type: .tall).isEmpty || ((game.imageURL?.path(percentEncoded: false).isEmpty) != nil) {
                    VStack {
                        Spacer()
                        HStack {
                            if networkMonitor.isEpicAccessible {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 5)
                            } else {
                                Image(systemName: "network.slash")
                                    .symbolEffect(.pulse)
                                    .foregroundStyle(.red)
                                    .help("Mythic cannot connect to the internet.")
                            }
                            Text("(\(game.title))")
                                .truncationMode(.tail)
                                .foregroundStyle(.placeholder)
                        }
                    }
                    .frame(width: 200, height: 400/1.5)
                } else {
                    Text("\(game.title)")
                        .font(.largeTitle)
                        .frame(width: 200, height: 400/1.5)
                }
            case .success(let image):
                ZStack {
                    image
                        .resizable()
                        .frame(width: 200, height: 400/1.5)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .blur(radius: 20)
                    
                    image
                        .resizable()
                        .frame(width: 200, height: 400/1.5)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .modifier(FadeInModifier())
                        .glur(offset: 0.55, interpolation: 0.4, radius: 20)
                        .overlay {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    ZStack {
                                        Image("EGFaceless")
                                            .resizable()
                                            .blur(radius: 1.3)
                                        
                                        Image("EGFaceless")
                                            .resizable()
                                    }
                                    .frame(width: 30, height: 30)
                                    .padding(10)
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Button {
                                        do {  }
                                    } label: {
                                        Image(systemName: "play.fill")
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.horizontal, 5)
                                    
                                    Button {
                                        do {  }
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.horizontal, 5)
                                    
                                    Button {
                                        do {  }
                                    } label: {
                                        Image(systemName: "gear")
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.horizontal, 5)
                                    
                                    Button {
                                        do {  }
                                    } label: {
                                        Image(systemName: "xmark.bin.fill")
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.horizontal, 5)
                                }
                                .padding()
                            }
                        }
                }
            case .failure:
                Text("\(game.title)")
                    .font(.largeTitle)
                    .frame(width: 200, height: 400/1.5)
            @unknown default:
                Image(systemName: "exclamationmark.triangle")
                    .symbolEffect(.appear)
                    .imageScale(.large)
                    .frame(width: 200, height: 400/1.5)
            }
        }
    }
}

#Preview {
    SwiftUIView()
        .environmentObject(NetworkMonitor())
}
