//
//  ContainersView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct ContainersView: View {
    @State private var isContainerCreationViewPresented = false
    
    var body: some View {
        ContainerListView()
            .navigationTitle("Containers")
        
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Managing their Windows® Instances"
                    presence.state = "Managing containers"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
            }
        
            .toolbar {
                if Engine.exists {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            isContainerCreationViewPresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add a container")
                    }
                    
                    if let containersDirectory = Wine.containersDirectory {
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                workspace.open(containersDirectory)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("Open Containers directory")
                        }
                    }
                }
            }
            .id(isContainerCreationViewPresented)

            .sheet(isPresented: $isContainerCreationViewPresented) {
                ContainerCreationView(isPresented: $isContainerCreationViewPresented)
            }
    }
}

#Preview {
    ContainersView()
}
