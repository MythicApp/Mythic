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
    
    // MARK: - GameImportView Struct
    struct GameImportView: View {
        
        // MARK: - Binding Variables
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        
        // MARK: - State Variables
        @State private var isProgressViewSheetPresented: Bool = false
        @State private var isErrorPresented: Bool = false
        @State private var errorContent: Substring = .init()
        
        @State private var type: GameType = .epic
        
        // MARK: - Body
        var body: some View { // TODO: split up epic and local into different view files
            VStack {
                Text("Import a Game")
                    .font(.title)
                    .multilineTextAlignment(.leading)
                
                Divider()
                
                Picker(String(), selection: $type) {
                    ForEach(Swift.type(of: type).allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                // MARK: - Import Epic (Legendary) Games
                switch type {
                case .epic:
                    LibraryView.GameImportView.Epic(
                        isPresented: $isPresented,
                        isProgressViewSheetPresented: $isProgressViewSheetPresented,
                        isGameListRefreshCalled: $isGameListRefreshCalled,
                        isErrorPresented: $isErrorPresented,
                        errorContent: $errorContent
                    )
                case .local:
                    LibraryView.GameImportView.Local(
                        isPresented: $isPresented,
                        isGameListRefreshCalled: $isGameListRefreshCalled
                    )
                }
            }
            
            .padding()
            
            .sheet(isPresented: $isProgressViewSheetPresented) {
                ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
            }
            
            .alert(isPresented: $isErrorPresented) {
                Alert(
                    title: Text("Error importing game"),
                    message: Text(errorContent)
                )
            }
        }
    }
}

#Preview {
    LibraryView.GameImportView(
        isPresented: .constant(true),
        isGameListRefreshCalled: .constant(false)
    )
}
