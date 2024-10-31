//
//  InstallStatus.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 3/12/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Foundation
import Charts // TODO: TODO

// MARK: - InstallStatusView Struct
/// A view displaying the installation status of a game.

struct InstallStatusView: View {
    // MARK: - Binding Variables
    @Binding var isPresented: Bool
    @ObservedObject private var operation: GameOperation = .shared
        
    // MARK: - Body
    var body: some View {
        if let current = operation.current {
            VStack {
                Text("Installing \"\(current.game.title)\"...")
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
                    Text("(\(operation.status.progress?.runtime ?? "00:00:00") Elapsed)")
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
                    
                    VStack {
                        Text("\(Int((operation.status.download?.downloaded ?? 0) * 1.048576)) MB Downloaded")
                        Text("\(Int((operation.status.download?.written ?? 0) * 1.048576)) MB Written")
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
            Text("No installation is currently running.")
                .font(.bold(.title)())
                .padding([.horizontal, .top])
        }
        
        HStack {
            GameInstallProgressView
                .OperationProgressView(showInitializer: false)

            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding([.horizontal, .bottom])
    }
}

// MARK: - Preview
#Preview {
    InstallStatusView(isPresented: .constant(true))
}
