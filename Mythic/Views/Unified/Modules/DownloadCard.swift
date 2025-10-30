//
//  DownloadCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 26/6/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct DownloadCard: View {
    @ObservedObject private var operation: GameOperation = .shared
    @State private var isHoveringOverDestructiveButton: Bool = false
    @State private var isImageEmpty: Bool = true

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

        return .init("STATUS UNKNOWN")
    }
    
    private var progressText: Text {
        let progress = Int(operation.status.progress?.percentage ?? 0)
        let speed = Int(operation.status.downloadSpeed?.raw ?? 0.0 * (1000000 / 1048576) /* MiB/s to MB/s conversion */)
        let eta = operation.status.progress?.eta ?? "00:00:00"
        return .init("\(progress)% • ↓ \(speed) MB/s • ⏲︎ \(eta)")
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.quinary)
            .frame(maxHeight: 120)
            .opacity(style == .prominent ? 0 : 1)
            .overlay {
                AsyncImage(url: URL(string: Legendary.getImage(of: game, type: .normal))) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .shimmering(animation: .easeInOut(duration: 1).repeatForever(autoreverses: false), bandSize: 1)
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .blur(radius: 20.0)
                            .modifier(FadeInModifier())
                            .onAppear {
                                withAnimation { isImageEmpty = false }
                            }
                            .onDisappear {
                                withAnimation { isImageEmpty = true }
                            }
                            .conditionalTransform(if: style != .prominent) { view in
                                view.clipShape(.rect(cornerRadius: 20))
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                            }
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay {
                                Image(systemName: "questionmark.circle")
                                    .symbolVariant(.fill)
                            }
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
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
                                .font(.system((style == .normal ? .title : .largeTitle), weight: .bold))
                            SubscriptedTextView(game.source.rawValue)
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

                        if operation.current?.game == game,
                           let optionalPacks = operation.current?.optionalPacks,
                           !optionalPacks.isEmpty {
                            Text("(\(optionalPacks.joined(separator: ", ")))")
                                .font(.footnote)
                                .foregroundStyle(.placeholder)
                        }
                    }
                    .conditionalTransform(if: !isImageEmpty) { view in
                        view.foregroundStyle(.white)
                    }
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
                            .clipShape(.capsule)
                            .help("Remove from download queue")
                        }
                    }
                    .padding(.trailing)
                }
            }
    }
}

#Preview {
    DownloadCard(game: .init(source: .local, title: "test", platform: .macOS, path: ""), style: .prominent)
}
