//
//  Library.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import SwiftyJSON

struct LibraryView: View {
    @State private var addGameModalPresented = false
    @State private var legendaryStatus: JSON = JSON()
    
    @State private var isGameListRefreshCalled: Bool = false
    
    var body: some View {
        GameListView(isRefreshCalled: $isGameListRefreshCalled)
        
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addGameModalPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isGameListRefreshCalled = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        
            .sheet(isPresented: $addGameModalPresented) {
                LibraryView.GameImportView(
                    isPresented: $addGameModalPresented,
                    isGameListRefreshCalled: $isGameListRefreshCalled
                )
                .fixedSize()
            }
    }
}

#Preview {
    GameListView(isRefreshCalled: .constant(false))
}
