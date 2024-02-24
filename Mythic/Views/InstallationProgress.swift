//
//  InstallationProgressView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 18/2/2024.
//

import SwiftUI

struct InstallationProgressView: View {
    @ObservedObject var gameModification: GameModification = .shared
    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    
    @State private var paused: Bool = false // https://github.com/derrod/legendary/issues/40
    
    var body: some View {
        HStack {
            Button {
                isInstallStatusViewPresented = true
            } label: {
                if let percentage: Double = (gameModification.status?["progress"])?["percentage"] as? Double {
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
            
            Button {
                // TODO: implement
            } label: {
                Image(systemName: "pause.fill")
                    .foregroundStyle(.orange)
                    .padding(.leading)
            }
            .buttonStyle(.plain)
            .controlSize(.regular)
            .disabled(true)
            .help("Not implemented yet")
            
            Button {
                isStopGameModificationAlertPresented = true
            } label: {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
                    .padding(.leading)
            }
            .buttonStyle(.plain)
            .controlSize(.regular)
        }
        .alert(isPresented: $isStopGameModificationAlertPresented) {
            stopGameModificationAlert(
                isPresented: $isStopGameModificationAlertPresented,
                game: gameModification.game ?? placeholderGame(type: .local)
            )
        }
        .sheet(isPresented: $isInstallStatusViewPresented) {
            InstallStatusView(isPresented: $isInstallStatusViewPresented)
        }
    }
}

#Preview {
    InstallationProgressView()
}
