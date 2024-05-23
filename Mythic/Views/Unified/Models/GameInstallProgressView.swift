//
//  GameInstallProgress.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 18/2/2024.
//

import SwiftUI

struct GameInstallProgressView: View {
    var withPercentage: Bool = true
    
    @ObservedObject private var operation: GameOperation = .shared
    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false
    
    @State private var paused: Bool = false // https://github.com/derrod/legendary/issues/40
    
    var body: some View {
        if let game = operation.current?.game {
            HStack {
                if let percentage = operation.status.progress?.percentage {
                    ProgressView(value: percentage, total: 100)
                        .progressViewStyle(.linear)
                        .help("\(Int(percentage))% complete")
                        .buttonStyle(.plain)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .help("Initializing...")
                        .buttonStyle(.plain)
                }
                
                if withPercentage, let percentage = operation.status.progress?.percentage {
                    Text("\(Int(percentage))%")
                }
                
                Button {
                    isInstallStatusViewPresented = true
                } label: {
                    Image(systemName: "info")
                        .padding([.vertical, .trailing], 5)
                }
                .clipShape(.circle)
                .help("Stop installing \"\(game.title)\"")
                    
                Button {
                    isStopGameModificationAlertPresented = true
                } label: {
                    Image(systemName: "xmark")
                        .padding([.vertical, .trailing], 5)
                        .foregroundStyle(isHoveringOverDestructiveButton ? .red : .primary)
                }
                .clipShape(.circle)
                .help("Stop installing \"\(game.title)\"")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) { isHoveringOverDestructiveButton = hovering }
                }
                .alert(isPresented: $isStopGameModificationAlertPresented) {
                    stopGameOperationAlert(
                        isPresented: $isStopGameModificationAlertPresented,
                        game: game
                    )
                }
                .sheet(isPresented: $isInstallStatusViewPresented) {
                    InstallStatusView(isPresented: $isInstallStatusViewPresented)
                        .padding()
                }
            }
        }
    }
}

#Preview {
    GameInstallProgressView()
}
