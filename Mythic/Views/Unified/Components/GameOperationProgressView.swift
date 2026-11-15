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
    var withLabel: Bool = true

    @State private var isGameOperationStatusViewPresented: Bool = false

    @State private var isStopGameOperationAlertPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false

    var body: some View {
        HStack {
            OperationProgressView(operation: operation, withLabel: withLabel)
                .layoutPriority(1)

            if operation.type.modifiesFiles, operation.isExecuting {
                Button {
                    isGameOperationStatusViewPresented = true
                } label: {
                    Label("Details", systemImage: "info")
                        .labelStyle(.iconOnly)
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
                Label("Cancel Operation", systemImage: "xmark")
                    .labelStyle(.iconOnly)
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

    var withLabel: Bool = false

    var body: some View {
        if operation.progressKVOBridge.fractionCompleted == 0 {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("\(operation.type.description), \(operation.game.title)")

            if withLabel {
                Text(operation.type.description)
                    .lineLimit(1)
            }
        } else {
            ProgressView(value: operation.progressKVOBridge.fractionCompleted)
                .help("\(operation.progressKVOBridge.fractionCompleted.formatted(.percent)) complete")
                .accessibilityLabel("\(operation.type.description), \(operation.game.title)")

            if withLabel {
                Text(operation.progressKVOBridge.fractionCompleted.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .layoutPriority(1)
                    .lineLimit(1)
                    .accessibilityHidden(true) // already conveyed by the progress indicator's value
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
