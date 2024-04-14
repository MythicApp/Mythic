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
        if operation.current?.game != nil {
            VStack {
                DownloadCard(game: operation.current!.game, style: .prominent)
                
                if !operation.queue.isEmpty {
                    Divider()
                }
                
                ForEach(operation.queue, id: \.self) { args in
                    DownloadCard(game: args.game, style: .normal)
                }
                .animation(.easeInOut, value: cardsUpdated)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct DownloadCard: View {
    
    @ObservedObject private var operation: GameOperation = .shared
    
    var game: Game
    var style: DownloadCardStyle
    enum DownloadCardStyle {
        case normal, prominent
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .frame(maxHeight: 120)
            .opacity({
                switch style {
                case .normal:
                    return 1
                case .prominent:
                    return 0
                }
            }())
            .overlay(alignment: .leading) {
                HStack {
                    CachedAsyncImage(url: .init(string: Legendary.getImage(of: game, type: .normal))) { phase in
                        switch phase {
                        case .empty:
                            switch style {
                            case .normal:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
                                    .shimmering(
                                        animation: .easeInOut(duration: 1)
                                            .repeatForever(autoreverses: false),
                                        bandSize: 1
                                    )
                            case .prominent:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
                                    .shimmering(
                                        animation: .easeInOut(duration: 1)
                                            .repeatForever(autoreverses: false),
                                        bandSize: 1
                                    )
                            }
                        case .success(let image):
                            switch style {
                            case .normal:
                                image
                                    .resizable()
                                    .blur(radius: 20.0)
                                    .clipShape(.rect(cornerRadius: 20))
                                    .modifier(FadeInModifier())
                            case .prominent:
                                image
                                    .resizable()
                                    .blur(radius: 20.0)
                                    .modifier(FadeInModifier())
                            }
                        case .failure:
                            // fallthrough
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.windowBackground)
                                .overlay {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.windowBackground)
                                .overlay {
                                    Image(systemName: "questionmark.circle.fill")
                                }
                        }
                    }
                    .overlay(alignment: .leading) {
                        HStack {
                            VStack {
                                HStack {
                                    Text(
                                        operation.current?.game == game ? "DOWNLOADING \(Image(systemName: "arrow.down.circle"))" :
                                            operation.queue.contains(where: { $0.game == game }) ? "QUEUED \(Image(systemName: "stopwatch"))" : "Unknown \(Image(systemName: "questionmark.circle"))"
                                    )
                                    .foregroundStyle(.secondary)
                                    .font({
                                        switch style {
                                        case .normal:
                                            return .caption
                                        case .prominent:
                                            return .callout
                                        }
                                    }())
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(game.title)
                                        .font(.bold({
                                            switch style {
                                            case .normal:
                                                return .title
                                            case .prominent:
                                                return .largeTitle
                                            }
                                        }())())
                                    SubscriptedTextView(game.type.rawValue)
                                    
                                    Spacer()
                                }
                                
                                if operation.current?.game == game {
                                    HStack {
                                        Text("\(Int(operation.status.progress?.percentage ?? 0))% • ↓ \(Int(operation.status.downloadSpeed?.raw ?? 0.0)) MB/s • ⏲︎ \(operation.status.progress?.eta ?? "00:00:00")")
                                            .foregroundStyle(.tertiary)
                                            .font({
                                                switch style {
                                                case .normal:
                                                    return .caption
                                                case .prominent:
                                                    return .callout
                                                }
                                            }())
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .foregroundStyle(.white)
                            
                            if operation.current?.game == game {
                                InstallationProgressView(withPercentage: false)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
    }
}

#Preview {
    DownloadsEvo()
    /*
     DownloadCard(game: .constant(.init(type: .epic, title: "")))
     .frame(height: 150)
     */
}
