//
//  ContainersView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwordRPC

struct ContainersView: View {
    @State private var isContainerCreationViewPresented = false

    var body: some View {
        Form {
            ContainerListView()
        }
        .formStyle(.grouped)
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
            if Engine.isInstalled {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isContainerCreationViewPresented = true
                    } label: {
                        Label("Add Container", systemImage: "plus")
                    }
                    .help("Add a container")
                }

                if let containersDirectory = Wine.containersDirectory {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            NSWorkspace.shared.open(containersDirectory)
                        } label: {
                            Label("Open Containers Folder", systemImage: "folder")
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
