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

    @Bindable private var operationManager: GameOperationManager = .shared

    @State private var isInstallStatusViewPresented: Bool = false

    @State private var isStopGameModificationAlertPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false

    var body: some View {
        if let currentOperation = operationManager.queue.first {
            HStack {
                OperationProgressView(operation: currentOperation, withPercentage: withPercentage)
                    .layoutPriority(1)

                Button {
                    isInstallStatusViewPresented = true
                } label: {
                    Image(systemName: "info")
                }
                .clipShape(.capsule)
                .help("View operation progress")
                .sheet(isPresented: $isInstallStatusViewPresented) {
                    InstallStatusView(isPresented: $isInstallStatusViewPresented)
                }

                Button {
                    isStopGameModificationAlertPresented = true
                } label: {
                    Image(systemName: "xmark")
                        .conditionalTransform(if: isHoveringOverDestructiveButton) { view in
                            view.foregroundStyle(.red)
                        }
                }
                .clipShape(.capsule)
                .help("Cancel operation")
                .onHover { hovering in
                    withAnimation {
                        isHoveringOverDestructiveButton = hovering
                    }
                }
                .alert("Do you wish to stop \(currentOperation.type.description.localizedLowercase) \(currentOperation.game.description)?",
                       isPresented: $isStopGameModificationAlertPresented) {
                    Button("Stop", role: .destructive) {
                        currentOperation.cancel()
                    }

                    Button("Cancel", role: .cancel, action: {})
                }
            }
        }
    }
}

extension GameInstallProgressView {
    struct OperationProgressView: View {
        var operation: GameOperation

        var withPercentage: Bool = false // TODO: @AppStorage
        var showInitializer: Bool = true

        var body: some View {
            ProgressView(value: operation.progressKVOBridge.fractionCompleted)
                .progressViewStyle(.linear)
                .help("\(operation.progressKVOBridge.fractionCompleted.formatted(.percent)) complete")
                .buttonStyle(.plain)

            if withPercentage {
                Text("\(operation.progressKVOBridge.fractionCompleted.formatted(.percent))")
                    .layoutPriority(1)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    GameInstallProgressView()
}
