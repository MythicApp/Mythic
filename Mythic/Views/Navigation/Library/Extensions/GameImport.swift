//
//  AddGameView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import OSLog

extension LibraryView {
    struct GameImportView: View {
        @Binding var isPresented: Bool
        
        @State private var type: GameType = .epic
        
        // MARK: - Body
        var body: some View {
            VStack {
                Text("Import")
                    .font(.title)
                    .multilineTextAlignment(.leading)
                
                Picker(String(), selection: $type) {
                    ForEach(Swift.type(of: type).allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                // MARK: - Import Epic (Legendary) Games
                switch type {
                case .epic:
                    LibraryView.GameImportView.Epic(isPresented: $isPresented)
                case .local:
                    LibraryView.GameImportView.Local(isPresented: $isPresented)
                        .scaledToFit() // FIXME: dirtyfix for clipping
                }
            }
            
            .padding()
        }
    }
}

#Preview {
    LibraryView.GameImportView(isPresented: .constant(true))
}
