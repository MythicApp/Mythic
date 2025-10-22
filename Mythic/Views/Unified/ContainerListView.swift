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
        if Engine.exists {
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
                    .disabled(!Engine.exists)
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(container.name)\"")
                    .sheet(isPresented: $isContainerConfigurationViewPresented) {
                        ContainerConfigurationView(containerURL: container.url, isPresented: $isContainerConfigurationViewPresented)
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
        } else {
            Engine.NotInstalledView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ContainerConfigurationView: View {
    var containerURL: URL
    @Binding var isPresented: Bool

    @State private var uninstallerActive: Bool = false
    @State private var configuratorActive: Bool = false
    @State private var registryEditorActive: Bool = false

    @State private var isOpenFileImporterPresented: Bool = false

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
                        isOpenFileImporterPresented = true
                    }
                    .fileImporter(
                        isPresented: $isOpenFileImporterPresented,
                        allowedContentTypes: [.exe]
                    ) { result in
                        switch result {
                        case .success(let url):
                            Task(priority: .userInitiated) {
                                do {
                                    try await Wine.run(
                                        arguments: [
                                            url.path(percentEncoded: false)
                                        ],
                                        containerURL: container.url
                                    )
                                } catch {
                                    openError = error
                                    isOpenAlertPresented = true
                                }
                            }
                        case .failure(let failure):
                            openError = failure
                            isOpenAlertPresented = true
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
                        // TODO: yeah
                    }
                    .disabled(true)
                    .help("Winetricks GUI support is currently broken.")

                    Button("Launch Uninstaller") {
                        Task { try await Wine.run(arguments: ["uninstaller"], containerURL: container.url) }
                    }
                    .disabled(uninstallerActive)

                    Button("Launch Configurator") {
                        Task { try await Wine.run(arguments: ["winecfg"], containerURL: container.url) }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            Task(priority: .background) { @MainActor in
                                configuratorActive = (try? await Wine.tasklist(containerURL: container.url).contains(where: { $0.name == "winecfg.exe" })) ?? false
                                // if !configuratorActive { timer.invalidate() } FIXME: swift 6
                            }
                        }
                    }
                    .disabled(configuratorActive)
                    
                    Button("Launch Registry Editor") {
                        Task { try await Wine.run(arguments: ["regedit"], containerURL: container.url) }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            Task(priority: .background) { @MainActor in
                                registryEditorActive = (try? await Wine.tasklist(containerURL: container.url).contains(where: { $0.name == "regedit.exe" })) ?? false
                                // if !registryEditorActive { timer.invalidate() } FIXME: swift 6
                            }
                        }
                    }
                    .disabled(registryEditorActive)
                    
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
                .fixedSize()
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
    Form {
        ContainerListView()
    }
    .formStyle(.grouped)
}
