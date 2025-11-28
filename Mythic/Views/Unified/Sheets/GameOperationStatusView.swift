//
//  InstallStatus.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 3/12/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Foundation
import Charts // TODO: TODO

struct InstallStatusView: View {
    @Binding var isPresented: Bool
    @Bindable private var operationManager: GameOperationManager = .shared

    let estimatedTimeRemainingFormatter: DateComponentsFormatter = {
        let formatter: DateComponentsFormatter = .init()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            if let currentOperation = operationManager.queue.first {
                Text(currentOperation.description)
                    .font(.title)
                    .bold()

                Form {
                    HStack {
                        Label("Progress", systemImage: "progress.indicator")

                        Spacer()

                        ProgressView(value: currentOperation.progressKVOBridge.fractionCompleted)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text(currentOperation.progressKVOBridge.fractionCompleted.formatted(.percent))
                    }

                    HStack {
                        Label("Files", systemImage: "folder")

                        Spacer()

                        Text("(\(currentOperation.progressKVOBridge.fileCompletedCount ?? 0)/\(currentOperation.progressKVOBridge.fileTotalCount ?? 0))")
                    }

                    if let estimatedTimeRemaining = currentOperation.progressKVOBridge.estimatedTimeRemaining {
                        HStack {
                            Label("Estimated Time Remaining", systemImage: "clock")

                            Spacer()

                            Text(estimatedTimeRemainingFormatter.string(from: estimatedTimeRemaining) ?? "Unknown")
                        }
                    }

                    if let throughput = currentOperation.progressKVOBridge.throughput {
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
                    "No download is currently in progress.",
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
    InstallStatusView(isPresented: .constant(true))
        .padding()
}
