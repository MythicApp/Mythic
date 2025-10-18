//
//  DownloadsEvo.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/4/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
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
                    ContentUnavailableView(
                        "No queued downloads.",
                        systemImage: "externaldrive.badge.checkmark",
                        description: .init("""
                        If you try to download more than one game at the same time, it'll be added to this queue.
                        """)
                    )
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
            ContentUnavailableView(
                "No new downloads! 😁",
                systemImage: "externaldrive.badge.checkmark",
                description: Text("""
                All downloads that may have been pending are complete.
                You may access the downloaded games in your library.
                """)
            )
        }
    }
}

#Preview {
    DownloadsEvo()
}
