//
//  GameInstallProgress.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 18/2/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct GameInstallProgressView: View {
    var withPercentage: Bool = true

    @ObservedObject private var operation: GameOperation = .shared
    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false
    @State private var paused: Bool = false // For issue: https://github.com/derrod/legendary/issues/40

    var body: some View {
        if operation.current?.game != nil {
            HStack {
                progressIndicator()

                infoButton()

                stopButton()
            }
        }
    }

    // MARK: - Helper Functions

    @ViewBuilder
    private func progressIndicator() -> some View {
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
    }

    @ViewBuilder
    private func infoButton() -> some View {
        Button {
            isInstallStatusViewPresented = true
        } label: {
            Image(systemName: "info")
                .padding([.vertical, .trailing], 5)
        }
        .clipShape(.circle)
        .help("Show install status")
        .sheet(isPresented: $isInstallStatusViewPresented) {
            InstallStatusView(isPresented: $isInstallStatusViewPresented)
                .padding()
        }
    }

    @ViewBuilder
    private func stopButton() -> some View {
        Button {
            isStopGameModificationAlertPresented = true
        } label: {
            Image(systemName: "xmark")
                .padding([.vertical, .trailing], 5)
                .foregroundStyle(isHoveringOverDestructiveButton ? .red : .primary)
        }
        .clipShape(.circle)
        .help("Stop installing")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHoveringOverDestructiveButton = hovering
            }
        }
        .alert(isPresented: $isStopGameModificationAlertPresented) {
            stopGameOperationAlert(isPresented: $isStopGameModificationAlertPresented, game: operation.current!.game)
        }
    }
}

#Preview {
    GameInstallProgressView()
}
