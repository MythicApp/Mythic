//
//  Downloads.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/3/2024.
//

import SwiftUI
import CachedAsyncImage

struct DownloadsView: View {
    @ObservedObject private var operation: GameOperation = .shared
    
    var body: some View {
        List { // TODO: FIXME: THIS IS A PREVIEW, MOVE TO THE TOP TO SEE THE CHANGES
            ForEach([operation.current?.args].compactMap { $0 } + operation.queue, id: \.self) { args in
                HStack {
                    VStack {
                        HStack {
                            if operation.current?.args == args {
                                Text("Now Installing")
                            } else if operation.queue.contains(args) {
                                Text("Queued")
                            } else {
                                Text("Status Unknown")
                            }
                            
                            Spacer()
                        }
                        HStack {
                            Text(args.game.title)
                                .font(.bold(.title3)())
                            
                            SubscriptedTextView(args.game.platform?.rawValue ?? "Unknown")
                            
                            SubscriptedTextView(args.game.type.rawValue)
                            
                            Spacer()
                        }
                    }
                    .background {
                        if let url = args.game.imageURL {
                            CachedAsyncImage(url: url, scale: 0.3) { phase in
                                if case .success(let image) = phase {
                                    HStack {
                                        image // TODO: make image width length of the text vstack + 50
                                            .resizable()
                                            .frame(width: 150, height: 10, alignment: .leading) // hate hardcoding frame sizes
                                            .blur(radius: 10)
                                            .modifier(FadeInModifier())
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if operation.current?.args == args {
                        InstallationProgressView()
                    } else if operation.queue.contains(args) {
                        Button {
                            operation.queue.removeAll(where: {$0 == args})
                        } label: {
                            Image(systemName: "xmark")
                                .padding(5)
                        }
                        .clipShape(.circle)
                    }
                }
            }
        }
    }
}

#Preview {
    DownloadsView()
}
