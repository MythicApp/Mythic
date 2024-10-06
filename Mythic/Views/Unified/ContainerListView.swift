//
//  ContainerListView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 19/2/2024.
//

import SwiftUI
import OSLog
import SwordRPC

struct ContainerListView: View {
    @State private var isContainerConfigurationViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var selectedContainerURL: URL = .init(filePath: .init())
    @State private var containerURLToDelete: URL = .init(filePath: .init())
    
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
                    Button(action: {
                        selectedContainerURL = container.url
                        isContainerConfigurationViewPresented = true
                    }, label: {
                        Image(systemName: "gear")
                    })
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(container.name)\"")
                    
                    Button {
                        containerURLToDelete = container.url
                        isDeletionAlertPresented = true
                    } label: {
                        Image(systemName: "xmark.bin")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .alert(isPresented: $isDeletionAlertPresented) {
                        let container = try? Wine.getContainerObject(url: containerURLToDelete)
                        return Alert(
                            title: .init("Are you sure you want to delete \"\(container?.name ?? "Unknown")\"?"),
                            message: .init("This process cannot be undone."),
                            primaryButton: .destructive(.init("Delete")) {
                                do {
                                    guard let containerURL = container?.url else { throw Wine.ContainerDoesNotExistError() }
                                    try Wine.deleteContainer(containerURL: containerURL)
                                } catch {
                                    Logger.file.error("Unable to delete container \(container?.name ?? ""): \(error.localizedDescription)")
                                    containerURLToDelete = .init(filePath: .init())
                                    isDeletionAlertPresented = false
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel")) {
                                containerURLToDelete = .init(filePath: .init())
                                isDeletionAlertPresented = false
                            }
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        
        .sheet(isPresented: $isContainerConfigurationViewPresented) {
            ContainerConfigurationView(containerURL: $selectedContainerURL, isPresented: $isContainerConfigurationViewPresented)
        }
    }
}

struct ContainerConfigurationView: View {
    @Binding var containerURL: URL
    @Binding var isPresented: Bool
    
    @State private var configuratorActive: Bool = false
    @State private var registryEditorActive: Bool = false
    
    @State private var isOpenAlertPresented = false
    @State private var openError: Error?
    
    init(containerURL: Binding<URL>, isPresented: Binding<Bool>) {
        self._containerURL = containerURL
        self._isPresented = isPresented
    }
    
    var body: some View {
        if let container = try? Wine.getContainerObject(url: self.containerURL) {
            VStack {
                Text("Configure \"\(container.name)\"")
                    .font(.title)
                
                Form {
                    ContainerSettingsView(selectedContainerURL: Binding($containerURL), withPicker: false)
                    // TODO: Add slider for scaling
                    // TODO: Add slider for winver
                }
                .formStyle(.grouped)
                
                HStack {
                    Spacer()
                    
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
                            configuratorActive = (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep winecfg.exe | grep -v grep"]))?.isEmpty == false
                            if !configuratorActive { timer.invalidate() }
                        }
                    }
                    .disabled(configuratorActive)
                    
                    Button("Launch Registry Editor") {
                        Task { try await Wine.command(arguments: ["regedit"], identifier: "regedit", containerURL: container.url) { _ in } }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            registryEditorActive = (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep regedit.exe | grep -v grep"]))?.isEmpty == false // TODO: tasklist
                            if !registryEditorActive { timer.invalidate() }
                        }
                    }
                    .disabled(registryEditorActive)
                    
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
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
