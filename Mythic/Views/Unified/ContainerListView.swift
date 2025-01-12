//
//  ContainerListView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/2/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import OSLog
import SwordRPC

struct ContainerListView: View {
    @State private var isContainerConfigurationViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    var body: some View {
        Form {
            ForEach(Wine.containerObjects) { container in
                HStack {
                    Text(container.name)
                    
                    Button {
                        workspace.open(container.url)
                    } label: {
                        Text("\(container.url.prettyPath()) \(Image(systemName: "link"))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .scaledToFit()
                    }
                    .buttonStyle(.accessoryBar)
                    
                    Spacer()

                    Button {
                        isContainerConfigurationViewPresented = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(container.name)\"")
                    .sheet(isPresented: $isContainerConfigurationViewPresented) {
                        ContainerConfigurationView(containerURL: container.url, isPresented: $isContainerConfigurationViewPresented)
                            .frame(minWidth: 600)
                    }

                    Button {
                        isDeletionAlertPresented = true
                    } label: {
                        Image(systemName: "xmark.bin")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .alert(isPresented: $isDeletionAlertPresented) {
                        return Alert(
                            title: .init("Are you sure you want to delete \"\(container.name)\"?"),
                            message: .init("This process cannot be undone."),
                            primaryButton: .destructive(.init("Delete")) {
                                do {
                                    try Wine.deleteContainer(containerURL: container.url)
                                } catch {
                                    Logger.file.error("Unable to delete container \(container.name): \(error.localizedDescription)")
                                    isDeletionAlertPresented = false
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel")) {
                                isDeletionAlertPresented = false
                            }
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ContainerConfigurationView: View {
    var containerURL: URL
    @Binding var isPresented: Bool
    
    @State private var configuratorActive: Bool = false
    @State private var registryEditorActive: Bool = false
    
    @State private var isOpenAlertPresented = false
    @State private var openError: Error?
    
    var body: some View {
        if let container = try? Wine.getContainerObject(url: self.containerURL) {
            VStack {
                Text("Configure \"\(container.name)\"")
                    .font(.title)
                    .padding([.horizontal, .top])

                Form {
                    ContainerSettingsView(
                        selectedContainerURL: .init(
                            get: { containerURL },
                            set: { _ in  }
                        ),
                        withPicker: false
                    )
                    // TODO: Add slider for scaling
                }
                .formStyle(.grouped)
                
                HStack {
                    Button("Open...") {
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseFiles = true
                        openPanel.allowsMultipleSelection = false
                        openPanel.allowedContentTypes = [.exe]
                        
                        if case .OK = openPanel.runModal(), let url = openPanel.urls.first {
                            Task {
                                do {
                                    try await Wine.command(arguments: [url.path(percentEncoded: false)], identifier: "custom_launch_\(url)", waits: true, containerURL: container.url) { _ in }
                                } catch {
                                    openError = error
                                    isOpenAlertPresented = true
                                }
                            }
                        }
                    }
                    .alert(isPresented: $isOpenAlertPresented) {
                        Alert(
                            title: .init("Error opening executable."),
                            message: .init(openError?.localizedDescription ?? "Unknown Error"),
                            dismissButton: .default(.init("OK"))
                        )
                    }
                    .onChange(of: isOpenAlertPresented) {
                        if !$1 { openError = nil }
                    }
                    
                    Button("Launch Winetricks") {
                        try? Wine.launchWinetricks(containerURL: container.url)
                    }
                    .disabled(true)
                    .help("Winetricks GUI support is currently broken.")
                    
                    Button("Launch Configurator") {
                        Task { try await Wine.command(arguments: ["winecfg"], identifier: "winecfg", containerURL: container.url) { _ in } }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            configuratorActive = (try? Process.execute(executableURL: .init(filePath: "/bin/bash"), arguments: ["-c", "ps aux | grep winecfg.exe | grep -v grep"]))?.isEmpty == false
                            if !configuratorActive { timer.invalidate() }
                        }
                    }
                    .disabled(configuratorActive)
                    
                    Button("Launch Registry Editor") {
                        Task { try await Wine.command(arguments: ["regedit"], identifier: "regedit", containerURL: container.url) { _ in } }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            registryEditorActive = (try? Process.execute(executableURL: .init(filePath: "/bin/bash"), arguments: ["-c", "ps aux | grep regedit.exe | grep -v grep"]))?.isEmpty == false // TODO: tasklist
                            if !registryEditorActive { timer.invalidate() }
                        }
                    }
                    .disabled(registryEditorActive)
                    
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
            }
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Configuring container \"\(container.name)\""
                    presence.state = "Configuring Container"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
            }
        } else {
            
        }
    }
}

#Preview {
    ContainerListView()
}
