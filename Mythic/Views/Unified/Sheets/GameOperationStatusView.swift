//
//  GameOperationStatusView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 3/12/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Foundation
import Charts // TODO: TODO

struct GameOperationStatusView: View {
    @Binding var isPresented: Bool
    @Binding var operation: GameOperation
    @Bindable private var operationManager: GameOperationManager = .shared

    let estimatedTimeRemainingFormatter: DateComponentsFormatter = {
        let formatter: DateComponentsFormatter = .init()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            if operation.isExecuting {
                Text(operation.description)
                    .font(.title)
                    .bold()

                Form {
                    HStack {
                        Label("Progress", systemImage: "progress.indicator")

                        Spacer()

                        ProgressView(value: operation.progressKVOBridge.fractionCompleted)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text(operation.progressKVOBridge.fractionCompleted.formatted(.percent))
                    }

                    if operation.type.modifiesFiles {
                        HStack {
                            Label("Files", systemImage: "folder")
                            
                            Spacer()
                            
                            Text("(\(operation.progressKVOBridge.fileCompletedCount ?? 0)/\(operation.progressKVOBridge.fileTotalCount ?? 0))")
                        }
                    }

                    if let estimatedTimeRemaining = operation.progressKVOBridge.estimatedTimeRemaining {
                        HStack {
                            Label("Estimated Time Remaining", systemImage: "clock")

                            Spacer()

                            Text(estimatedTimeRemainingFormatter.string(from: estimatedTimeRemaining) ?? "Unknown")
                        }
                    }

                    if let throughput = operation.progressKVOBridge.throughput {
                        HStack {
                            Label("Throughput", systemImage: "arrow.up.arrow.down")

                            Spacer()

                            Text("\(ByteCountFormatter.string(fromByteCount: Int64(throughput), countStyle: .file))/s")
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "This operation isn't currently running.",
                    systemImage: "externaldrive.badge.checkmark"
                )
            }

            HStack {
                Button("Close", action: { isPresented = false })
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 750)
        }
    }
}

#Preview {
    GameOperationStatusView(isPresented: .constant(true), operation: .constant(.init(game: placeholderGame(type: Game.self), type: .install, function: { _ in })))
        .padding()
}
