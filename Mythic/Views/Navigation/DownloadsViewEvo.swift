//
//  DownloadsEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/4/2024.
//

import SwiftUI
import CachedAsyncImage
import Shimmer

struct DownloadsEvo: View {
    @ObservedObject private var operation: GameOperation = .shared
    @State private var cardsUpdated: Bool = false
    
    var body: some View {
        if let currentGame = operation.current?.game {
            VStack {
                DownloadCard(game: currentGame, style: .prominent)
                
                Divider()
                
                if operation.queue.isEmpty {
                    Text("No other downloads are pending.")
                        .bold()
                        .padding()
                } else {
                    LazyVStack {
                        ForEach(operation.queue, id: \.self) { args in
                            DownloadCard(game: args.game, style: .normal)
                        }
                        .animation(.easeInOut, value: cardsUpdated)
                    }
                }
                
                Spacer()
            }
            .padding()
        } else {
            Text("No other downloads are pending.")
                .font(.bold(.title)())
        }
    }
}

#Preview {
    DownloadsEvo()
}
