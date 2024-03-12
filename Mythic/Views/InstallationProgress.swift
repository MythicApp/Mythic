//
//  InstallationProgressView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 18/2/2024.
//

import SwiftUI

struct InstallationProgressView: View {
    var withPercentage: Bool = true
    
    @ObservedObject private var gameModification: GameModification = .shared
    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    @State private var hoveringOverDestructiveButton: Bool = false
    
    @State private var paused: Bool = false // https://github.com/derrod/legendary/issues/40
    
    var body: some View {
        if let game = gameModification.game {
            HStack {
                Button {
                    isInstallStatusViewPresented = true
                } label: {
                    if let percentage = gameModification.status?["progress"]?["percentage"] as? Double {
                        ProgressView(value: percentage, total: 100)
                            .progressViewStyle(.linear)
                            .help("\(Int(percentage))% complete")
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .help("Initializing...")
                    }
                }
                .buttonStyle(.plain)
                
                if withPercentage, let percentage = gameModification.status?["progress"]?["percentage"] as? Double {
                    Text("\(Int(percentage))%")
                }
                    
                Button {
                    isStopGameModificationAlertPresented = true
                } label: {
                    Image(systemName: "xmark")
                        .padding(5)
                        .foregroundStyle(hoveringOverDestructiveButton ? .red : .primary)
                }
                .clipShape(.circle)
                .help("Stop installing \"\(game.title)\"")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) { hoveringOverDestructiveButton = hovering }
                }
                .alert(isPresented: $isStopGameModificationAlertPresented) {
                    stopGameModificationAlert(
                        isPresented: $isStopGameModificationAlertPresented,
                        game: game
                    )
                }
                .sheet(isPresented: $isInstallStatusViewPresented) {
                    InstallStatusView(isPresented: $isInstallStatusViewPresented)
                }
            }
        }
    }
}

#Preview {
    InstallationProgressView()
}
