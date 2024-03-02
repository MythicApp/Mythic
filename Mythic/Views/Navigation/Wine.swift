//
//  Wine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct WineView: View {
    @State private var isBottleCreationViewPresented = false
    
    var body: some View {
        BottleListView()
            .navigationTitle("Bottles")
        
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.state = "Managing bottles"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
            }
        
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isBottleCreationViewPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a bottle")
                }
            }
        
            .sheet(isPresented: $isBottleCreationViewPresented) {
                BottleCreationView(isPresented: $isBottleCreationViewPresented)
            }
    }
}

#Preview {
    WineView()
}
