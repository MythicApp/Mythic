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
    @Bindable private var operationManager: GameOperationManager = .shared

    var body: some View {
        // will also implicitly check if currentOperation is empty
        if let currentOperation = operationManager.queue.first {
            VStack {
                DownloadCard(game: .constant(currentOperation.game))

                Divider()
                
                if operationManager.queue.count == 1 {
                    ContentUnavailableView(
                        "No queued game operations.",
                        systemImage: "externaldrive.badge.checkmark",
                        description: .init("""
                            If you attempt to download more than one game at the same time, it'll be added to this queue.
                            """)
                    )
                } else {
                    ForEach(operationManager.queue.dropFirst(), id: \.self) { operation in
                        DownloadCard(game: .constant(operation.game))
                    }
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
