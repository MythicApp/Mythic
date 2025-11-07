//
//  DownloadsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/4/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Shimmer

struct DownloadsView: View {
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
                        If you attempt to download more than one game at the same time, it'll be added to this queue.
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
    DownloadsView()
}
