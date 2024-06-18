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

struct DownloadCard: View {
    @ObservedObject private var operation: GameOperation = .shared
    @State private var isHoveringOverDestructiveButton: Bool = false
    
    var game: Game
    var style: DownloadCardStyle
    
    enum DownloadCardStyle {
        case normal, prominent
    }
    
    private var statusText: Text {
        if operation.current?.game == game {
            return .init("\(operation.current?.type.rawValue.uppercased() ?? "MODIFYING") \(Image(systemName: "arrow.down.circle"))")
        } else if operation.queue.contains(where: { $0.game == game }) {
            return .init("QUEUED \(Image(systemName: "stopwatch"))")
        }
        return .init("MODIFYING")
    }
    
    private var progressText: Text {
        let progress = Int(operation.status.progress?.percentage ?? 0)
        let speed = Int(operation.status.downloadSpeed?.raw ?? 0.0 * (1000000 / 1048576))
        let eta = operation.status.progress?.eta ?? "00:00:00"
        return .init("\(progress)% • ↓ \(speed) MB/s • ⏲︎ \(eta)")
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .frame(maxHeight: 120)
            .opacity(style == .prominent ? 0 : 1)
            .overlay {
                CachedAsyncImage(url: URL(string: Legendary.getImage(of: game, type: .normal))) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .shimmering(animation: .easeInOut(duration: 1).repeatForever(autoreverses: false), bandSize: 1)
                    case .success(let image):
                        if case .prominent = style {
                            image.resizable()
                                .blur(radius: 20.0)
                                .modifier(FadeInModifier())
                        } else {
                            image.resizable()
                                .blur(radius: 20.0)
                                .clipShape(.rect(cornerRadius: 20))
                                .modifier(FadeInModifier())
                        }
                    case .failure:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay { Image(systemName: "exclamationmark.triangle.fill") }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay { Image(systemName: "questionmark.circle.fill") }
                    }
                }
                .ignoresSafeArea()
                
                HStack {
                    VStack(alignment: .leading) {
                        statusText
                            .foregroundStyle(.secondary)
                            .font(style == .normal ? .caption : .callout)
                        
                        HStack {
                            Text(game.title)
                                .font(.system(style == .normal ? .title : .largeTitle, weight: .bold))
                            SubscriptedTextView(game.type.rawValue)
                            Spacer()
                        }
                        
                        if operation.current?.game == game {
                            HStack {
                                progressText
                                    .foregroundStyle(.tertiary)
                                    .font(style == .normal ? .caption : .callout)
                                Spacer()
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    
                    Group {
                        if operation.current?.game == game {
                            GameInstallProgressView(withPercentage: false)
                        } else if operation.queue.contains(where: { $0.game == game }) {
                            Button {
                                operation.queue.removeAll(where: { $0.game == game })
                            } label: {
                                Image(systemName: "minus")
                                    .padding(5)
                                    .foregroundStyle(isHoveringOverDestructiveButton ? .red : .primary)
                            }
                            .clipShape(.circle)
                            .help("Remove from download queue")
                        }
                    }
                    .padding(.trailing)
                }
            }
    }
}

#Preview {
    DownloadsEvo()
}
