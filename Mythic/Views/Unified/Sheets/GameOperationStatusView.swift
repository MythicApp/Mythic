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

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            if let currentOperation = operationManager.queue.first {
                Text(currentOperation.description)
                    .font(.title)
                    .bold()

                Form {
                    HStack {
                        Text("Progress")

                        Spacer()

                        ProgressView(value: currentOperation.progressKVOBridge.fractionCompleted)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text(currentOperation.progressKVOBridge.fractionCompleted.formatted(.percent))
                    }

                    HStack {
                        Text("Files")

                        Spacer()

                        Text("(\(currentOperation.progressKVOBridge.fileCompletedCount?.formatted(.percent) ?? "?")/\(currentOperation.progressKVOBridge.fileCompletedCount?.formatted(.percent) ?? "?"))")
                    }

                    if let estimatedTimeRemaining = currentOperation.progressKVOBridge.estimatedTimeRemaining {
                        HStack {
                            Text("Estimated Time Remaining")

                            Spacer()

                            Image(systemName: "arrow.down.to.line")
                            Text(Date.now.addingTimeInterval(estimatedTimeRemaining), format: .dateTime)
                        }
                    }

                    HStack {
                        Text("Throughput")

                        Spacer()

                        Text("\(ByteCountFormatter.string(fromByteCount: Int64(currentOperation.progressKVOBridge.throughput), countStyle: .file))/s")
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
