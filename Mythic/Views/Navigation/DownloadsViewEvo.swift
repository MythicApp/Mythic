//
//  DownloadsEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/4/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
                    ForEach(operation.queue, id: \.self) { args in
                        DownloadCard(game: args.game, style: .normal)
                    }
                    .animation(.easeInOut, value: cardsUpdated)
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
