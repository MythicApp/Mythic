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

/// A view displaying the installation status of a game.
struct InstallStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var operation: GameOperation = .shared

    var body: some View {
        if let current = operation.current {
            VStack {
                Text("\(current.type.rawValue.capitalized) \"\(current.game.title)\"...")
                    .font(.title)

                Text("\(Int(operation.status.progress?.percentage ?? 0))% Complete")
                    .font(.title3)
                    .foregroundStyle(.placeholder)
            }
            .padding([.horizontal, .top])

            Form {
                HStack {
                    Text("Progress:")
                    Spacer()
                    Text("\(Int(operation.status.progress?.percentage ?? 0))%")
                    Text("(\(operation.status.progress?.downloadedObjects ?? 0)/\(operation.status.progress?.totalObjects ?? 0) Objects)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Time Remaining:")
                    Spacer()
                    Text("\(operation.status.progress?.eta ?? "Unknown")")
                    Text("(\(operation.status.progress?.runtime ?? "N/A") Elapsed)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Download Speed:")
                    Spacer()
                    Text("\(Int((operation.status.downloadSpeed?.raw ?? 0) * 1.048576)) MB/s")
                    Text("(raw)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .trailing) {
                        Text("\(Int((operation.status.download?.downloaded ?? 0) * 1.048576)) MB Downloaded")
                            .lineLimit(1)
                        
                        Text("\(Int((operation.status.download?.written ?? 0) * 1.048576)) MB Written")
                            .lineLimit(1)
                    }
                    .font(.bold(.footnote)())
                    .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Disk Speed:")
                    Spacer()
                    
                    Text("\(Int((operation.status.diskSpeed?.read ?? 0) * 1.048576)) MB/s")
                    Text("(read)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int((operation.status.diskSpeed?.write ?? 0) * 1.048576)) MB/s")
                    Text("(write)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                /* works! // TODO: maybe add an advanced metrics setting that uses this
                 ForEach(Array(Mirror(reflecting: operation.status.progress ?? .init(percentage: 0, downloadedObjects: 0, totalObjects: 0, runtime: "0", eta: "0")).children), id: \.label) { child in
                 if let label = child.label {
                 Text("\(String(describing: label)): \(String(describing: child.value))")
                 }
                 }
                 */
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView(
                "No download is currently in progress.",
                systemImage: "externaldrive.badge.checkmark"
            )
        }
        
        HStack {
            GameInstallProgressView.OperationProgressView(operation: operation, showInitializer: false)

            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding([.horizontal, .bottom])
        .frame(maxWidth: 750)
    }
}

#Preview {
    InstallStatusView(isPresented: .constant(true))
}
