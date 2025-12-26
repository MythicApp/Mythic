//
//  ContainerListView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import OSLog
import SwordRPC

struct ContainerListView: View {
    @State private var isContainerConfigurationViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var isContainerCreationViewPresented = false
    
    var body: some View {
        if Engine.isInstalled {
            ForEach(Wine.containerObjects) { container in
                HStack {
                    Text(container.name)

                    Button {
                        NSWorkspace.shared.open(container.url)
                    } label: {
                        Text("\(container.url.prettyPath) \(Image(systemName: "link"))")
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
                    .disabled(!Engine.isInstalled)
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(container.name)\"")
                    .sheet(isPresented: $isContainerConfigurationViewPresented) {
                        ContainerConfigurationView(containerURL: .constant(container.url),
                                                   isPresented: $isContainerConfigurationViewPresented)
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
        } else if Wine.containerURLs.isEmpty {
            ContentUnavailableView(
                "No containers are initialised. 😢",
                systemImage: "cube.transparent",
                description: Text("""
                    Containers will appear here.
                    You must create a container in order to launch a Windows® game.
                    """)
            )
            
            Button {
                isContainerCreationViewPresented = true
            } label: {
                Label("Create Container", systemImage: "plus")
                    .padding(5)
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $isContainerCreationViewPresented) {
                ContainerCreationView(isPresented: $isContainerCreationViewPresented)
            }
        } else {
            Engine.NotInstalledView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ContainerConfigurationView: View {
    @Binding var containerURL: URL
    @Binding var isPresented: Bool

    @State private var isUninstallerActive: Bool = false
    @State private var isConfiguratorActive: Bool = false
    @State private var isRegistryEditorActive: Bool = false

    @State private var isOpenFileImporterPresented: Bool = false

    @State private var isOpenAlertPresented = false
    @State private var openError: Error?
    
    var body: some View {
        if let container = try? Wine.getContainerObject(at: self.containerURL) {
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
                                    let process: Process = .init()
                                    process.arguments = [url.path]
                                    Wine.transformProcess(process, containerURL: container.url)
                                    
                                    try process.run()
                                    
                                    process.waitUntilExit()
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

                    Button("Install/Uninstall...") {
                        Task {
                            let process: Process = .init()
                            process.arguments = ["uninstaller"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()
                            
                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "uninstaller.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isUninstallerActive = isActive }
                            }
                        }
                    }
                    .disabled(isUninstallerActive)

                    Button("Configure Container...") {
                        let containerURL = container.url

                        Task {
                            let process: Process = .init()
                            process.arguments = ["winecfg"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()

                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "winecfg.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isConfiguratorActive = isActive }
                            }
                        }
                    }
                    .disabled(isConfiguratorActive)
                    
                    Button("Launch Registry Editor") {
                        let containerURL = container.url

                        Task {
                            let process: Process = .init()
                            process.arguments = ["regedit"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()

                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "regedit.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isRegistryEditorActive = isActive }
                            }
                        }
                    }
                    .disabled(isRegistryEditorActive)
                    
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
