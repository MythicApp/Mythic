//
//  OperationCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 26/6/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct ProminentOperationCard: View {
    @Binding var operation: GameOperation
    
    @State private var isImageEmpty: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GameImageCard(url: operation.game.horizontalImageURL, isImageEmpty: $isImageEmpty)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
                
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Label(operation.type.description.uppercased(), systemImage: "progress.indicator")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        HStack {
                            GameCard.TitleAndInformationView(game: .constant(operation.game),
                                                             withSubscriptedInfo: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .customTransform { view in
                        if #available(macOS 26.0, *) {
                            view
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 20.0))
                        } else {
                            view
                        }
                    }
                    
                    HStack {
                        OperationCard.StatusView(operation: $operation, hideStatusIfUnknown: true)
                            .customTransform { view in
                                if #available(macOS 26.0, *) {
                                    view
                                        .padding()
                                        .glassEffect(in: .rect(cornerRadius: 20.0))
                                } else {
                                    view
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .customTransform { view in
                    if #available(macOS 26.0, *) {
                        view
                    } else {
                        view
                            .padding()
                            .background(in: .rect(cornerRadius: 20.0))
                    }
                }
                .padding()
                .frame(width: geometry.size.width * 0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }
}

struct OperationCard: View {
    @Binding var operation: GameOperation
    
    @State private var isImageEmpty: Bool = true
    
    var body: some View {
        ZStack {
            GameImageCard(url: operation.game.horizontalImageURL, isImageEmpty: $isImageEmpty)
                .aspectRatio(16/9, contentMode: .fill)
            
            HStack {
                if operation.game.isFallbackImageAvailable, isImageEmpty {
                    GameCard.FallbackImageCard(game: .constant(operation.game))
                        .frame(width: 70, height: 70)
                        .padding()
                }
                
                VStack(alignment: .leading) {
                    Text(operation.game.title)
                        .font(.system(.title, weight: .bold))
                    
                    HStack {
                        GameCard.SubscriptedInfoView(game: .constant(operation.game))
                    }
                }
                .foregroundStyle(isImageEmpty ? Color.primary : Color.white)
                .padding(.horizontal)
                
                Spacer()
                
                StatusView(operation: $operation)
                    .padding(.trailing)
            }
            .padding()
            .customTransform { view in
                if #available(macOS 26.0, *) {
                    view
                        .glassEffect(in: .rect(cornerRadius: 20.0))
                        .padding()
                } else {
                    view
                        .background(in: .rect(cornerRadius: 20.0))
                }
            }
        }
        .frame(height: ListGameCard.defaultHeight)
        .clipShape(.rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
    }
}

extension OperationCard {
    struct StatusView: View {
        @Binding var operation: GameOperation
        @Bindable private var operationManager: GameOperationManager = .shared
        
        var hideStatusIfUnknown: Bool = false
        
        var body: some View {
            if operation.isExecuting {
                InteractiveGameOperationProgressView(operation: $operation, withPercentage: true)
                    .clipShape(.capsule)
            } else if operationManager.queue.contains(operation), !operation.isCancelled {
                Button {
                    operation.cancel()
                } label: {
                    Image(systemName: "minus")
                        .padding(2)
                }
                .help("Remove operation from queue")
            } else if operation.isCancelled {
                Image(systemName: "checkmark")
                    .help("This operation has been cancelled.")
            } else if !hideStatusIfUnknown {
                Image(systemName: "questionmark")
                    .help("This operation's status is unknown.")
            }
        }
    }
}

#Preview {
    OperationCard(operation: .constant(.init(game: placeholderGame(type: Game.self), type: .install, function: { _ in })))
        .padding()
        .environmentObject(NetworkMonitor.shared)
}
