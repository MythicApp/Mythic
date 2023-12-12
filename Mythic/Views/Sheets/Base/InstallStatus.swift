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

import SwiftUI
import Foundation
import Charts // TODO: TODO

// MARK: - InstallStatusView Struct
/// A view displaying the installation status of a game.

struct InstallStatusView: View {
    // MARK: - Binding Variables
    @Binding var isPresented: Bool
    
    // MARK: - Variables
    private let status: Legendary.InstallStatus = Legendary.Installing.installStatus
    
    // MARK: - Body
    var body: some View {
        VStack {
            // MARK: Title
            Text("Downloading \(Legendary.Installing.game?.title ?? "[unknown]")…")
                .font(.title)
            
            GroupBox {
                Text("Progress: \(Int(status.progress?.percentage ?? 0))% (\(status.progress?.downloaded ?? 0)/\(status.progress?.total ?? 0) objects)")
                Text("Downloaded \(status.download?.downloaded ?? 0) MiB, Written \(status.download?.written ?? 0)")
                Text("Elapsed: \("\(status.progress?.runtime ?? "[unknown]")"), ETA: \("\(status.progress?.eta ?? "[unknown]")")")
            }
            .fixedSize()
            
            // MARK: Close Button
            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.accent)
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    InstallStatusView(isPresented: .constant(true))
}
