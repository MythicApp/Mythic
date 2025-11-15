//
//  GameInstallProgress.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct GameInstallProgressView: View {
    var withPercentage: Bool = true

    @ObservedObject private var operation: LegacyGameOperation = .shared
    @State private var isInstallStatusViewPresented: Bool = false
    @State private var paused: Bool = false // For issue: https://github.com/derrod/legendary/issues/40

    var body: some View {
        if operation.current != nil {
            HStack {
                OperationProgressView(operation: operation, withPercentage: withPercentage)
                    .layoutPriority(1)

                StatusButton()

                StopButton(operation: operation)
            }
        }
    }
}

extension GameInstallProgressView {
    struct StatusButton: View {
        @State private var isInstallStatusViewPresented: Bool = false

        var body: some View {
            Button {
                isInstallStatusViewPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .clipShape(.capsule)
            .help("Show install status")
            .sheet(isPresented: $isInstallStatusViewPresented) {
                InstallStatusView(isPresented: $isInstallStatusViewPresented)
            }
        }
    }

    struct StopButton: View {
        @ObservedObject var operation: LegacyGameOperation

        @State private var isStopGameModificationAlertPresented: Bool = false
        @State private var isHoveringOverDestructiveButton: Bool = false

        var body: some View {
            if let currentOperation = operation.current {
                Button {
                    isStopGameModificationAlertPresented = true
                } label: {
                    Image(systemName: "xmark")
                        .conditionalTransform(if: isHoveringOverDestructiveButton) { view in
                            view.foregroundStyle(.red)
                        }
                }
                .clipShape(.capsule)
                .help("Stop installing")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHoveringOverDestructiveButton = hovering
                    }
                }
                .alert(isPresented: $isStopGameModificationAlertPresented) {
                    stopLegacyGameOperationAlert(
                        isPresented: $isStopGameModificationAlertPresented,
                        game: currentOperation.game
                    )
                }
            }
        }
    }
}

extension GameInstallProgressView {
    struct OperationProgressView: View {
        @ObservedObject var operation: LegacyGameOperation

        var withPercentage: Bool = false
        var showInitializer: Bool = true

        var body: some View {
            if let percentage = operation.status.progress?.percentage {
                ProgressView(value: percentage, total: 100)
                    .progressViewStyle(.linear)
                    .help("\(Int(percentage))% complete")
                    .buttonStyle(.plain)
            } else if showInitializer {
                ProgressView()
                    .progressViewStyle(.linear)
                    .help("Initializing...")
                    .buttonStyle(.plain)
            }

            if withPercentage, let percentage = operation.status.progress?.percentage {
                Text("\(Int(percentage))%")
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    GameInstallProgressView()
}
