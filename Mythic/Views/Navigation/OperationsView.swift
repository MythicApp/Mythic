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
            if !operationManager.queue.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        VStack {
                            if let prominentOperation = operationManager.queue.first(where: { $0.isExecuting && $0.type.modifiesFiles }) {
                                ProminentOperationCard(operation: .constant(prominentOperation))
                                    .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                                    .customTransform { view in
                                        if #available(macOS 26.0, *) {
                                            view.backgroundExtensionEffect()
                                        } else {
                                            view
                                        }
                                    }
                                
                                Divider()
                            }
                            
                            let nonProminentOperations = operationManager.queue.filter({ $0 != operationManager.queue.first(where: { $0.isExecuting && $0.type.modifiesFiles }) })
                            
                            if nonProminentOperations.isEmpty {
                                ContentUnavailableView(
                                    "Nothing Else Queued",
                                    systemImage: "checkmark",
                                    description: .init("Operations you start while another is running will wait here.")
                                )
                            } else {
                                ForEach(nonProminentOperations) { operation in
                                    OperationCard(operation: .constant(operation))
                                }
                            }
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "No Active Operations",
                    systemImage: "checkmark.circle",
                    description: Text("""
                        Installs, updates and other game operations will appear here while they're in progress.
                        You'll find your installed games in your Library.
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
