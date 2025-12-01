//
//  OperationsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/4/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Shimmer
import SwordRPC

struct OperationsView: View {
    @Bindable private var operationManager: GameOperationManager = .shared
    
    var body: some View {
        Group {
            if let currentOperation = operationManager.queue.first {
                GeometryReader { geometry in
                    ScrollView {
                        VStack {
                            ProminentOperationCard(operation: .constant(currentOperation))
                                .padding()
                                .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                            
                            if operationManager.queue.count <= 1 {
                                ContentUnavailableView(
                                    "No new game operations are queued.",
                                    systemImage: "checkmark",
                                    description: .init("If you attempt to download more than one game at the same time, it'll be added to this queue.")
                                )
                            } else {
                                ForEach(operationManager.queue.dropFirst(), id: \.self) { operation in
                                    OperationCard(operation: .constant(operation))
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No new operations! 😁",
                    systemImage: "checkmark",
                    description: Text("""
                        All game operations that may have been pending are complete.
                        You may access downloaded games in your [\(Image(systemName: "books.vertical")) Library].
                        """)
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .customTransform { view in
            if #available(macOS 15.0, *) {
                view
                    .toolbar(removing: .title)
                    .toolbarBackgroundVisibility(.hidden) // dirtyfixes toolbar reappearance on view reload in navigationsplitview
            } else {
                view
                    .toolbarBackground(.hidden) // dirtyfixes toolbar reappearance on view reload in navigationsplitview
            }
        }
        
        .navigationTitle("Operations")
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Waiting for games to finish operating"
                presence.state = "Viewing Operations"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
    }
}

#Preview {
    OperationsView()
}
