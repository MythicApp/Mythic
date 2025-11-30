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

    @State private var isInstallStatusViewPresented: Bool = false

    @State private var isStopGameOperationAlertPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false

    var body: some View {
        HStack {
            OperationProgressView(operation: operation, withPercentage: withPercentage)
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
                    .padding()
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

#Preview {
    InteractiveGameOperationProgressView(
        operation: .constant(
            .init(game: placeholderGame(type: Game.self),
                  type: .install,
                  function: { _ in })
        )
    )
}
