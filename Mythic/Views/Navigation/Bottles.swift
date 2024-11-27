//
//  Bottles.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the Licen[...]
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Gener[...]
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct BottlesView: View {
    @State private var isBottleCreationViewPresented = false
    
    var body: some View {
        BottleListView()
            .navigationTitle("Bottles")
            .backgroundTask {
                updateDiscordPresence()
            }
            .toolbar {
                if Engine.exists {
                    ToolbarItemGroup {
                        AddBottleButton(isPresented: $isBottleCreationViewPresented)
                        OpenBottlesDirectoryButton()
                    }
                }
            }
            .sheet(isPresented: $isBottleCreationViewPresented) {
                BottleCreationView(isPresented: $isBottleCreationViewPresented)
            }
    }
    
    private func updateDiscordPresence() {
        discordRPC.setPresence({
            var presence: RichPresence = .init()
            presence.details = "Managing their Windows® Instances"
            presence.state = "Managing bottles"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
    }
}

struct AddBottleButton: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "plus")
        }
        .help("Add a bottle")
    }
}

struct OpenBottlesDirectoryButton: View {
    var body: some View {
        if let bottlesDirectory = Wine.bottlesDirectory {
            Button {
                workspace.open(bottlesDirectory)
            } label: {
                Image(systemName: "folder")
            }
            .help("Open Bottles directory")
        }
    }
}

#Preview {
    BottlesView()
}
