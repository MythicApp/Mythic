//
//  GameInstallProgress.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct InteractiveGameOperationProgressView: View {
    @Binding var operation: GameOperation
    var withPercentage: Bool = true

    @State private var isGameOperationStatusViewPresented: Bool = false

    @State private var isStopGameOperationAlertPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false

    var body: some View {
        HStack {
            OperationProgressView(operation: operation, withPercentage: withPercentage)
                .layoutPriority(1)

            if operation.type.modifiesFiles, operation.isExecuting {
                Button {
                    isGameOperationStatusViewPresented = true
                } label: {
                    Image(systemName: "info")
                }
                .clipShape(.capsule)
                .help("View operation progress")
                .sheet(isPresented: $isGameOperationStatusViewPresented) {
                    GameOperationStatusView(isPresented: $isGameOperationStatusViewPresented, operation: $operation)
                        .padding()
                }
            }

            Button {
                isStopGameOperationAlertPresented = true
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
            .alert("Do you wish to stop \(operation.type.description.localizedLowercase) \(operation.game.description)?",
                   isPresented: $isStopGameOperationAlertPresented) {
                Button("Stop", role: .destructive) {
                    operation.cancel()
                }

                Button("Cancel", role: .cancel, action: {})
            }
        }
    }
}

struct OperationProgressView: View {
    var operation: GameOperation

    var withPercentage: Bool = false

    var body: some View {
        if operation.progressKVOBridge.fractionCompleted == 0 {
            ProgressView()
                .controlSize(.small)
            
            Text(operation.type.description)
                .lineLimit(1)
        } else {
            ProgressView(value: operation.progressKVOBridge.fractionCompleted)
                .help("\(operation.progressKVOBridge.fractionCompleted.formatted(.percent)) complete")
            
            if withPercentage {
                Text(operation.progressKVOBridge.fractionCompleted.formatted(.percent))
                    .layoutPriority(1)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    InteractiveGameOperationProgressView(
        operation: .constant(
            .init(game: placeholderGame(type: Game.self),
                  type: .install,
                  function: { _ in })
        )
    )
}
