//
//  BottleList.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 19/2/2024.
//

import SwiftUI
import OSLog
import SwordRPC

struct BottleListView: View {
    @State private var isBottleConfigurationViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var selectedBottleURL: URL = .init(filePath: .init())
    @State private var bottleURLToDelete: URL = .init(filePath: .init())
    
    @State private var isBottleCreationViewPresented: Bool = false
    
    var body: some View {
        Form {
            ForEach(Wine.bottleObjects) { bottle in
                HStack {
                    Text(bottle.name)
                    
                    Button {
                        workspace.open(bottle.url)
                    } label: {
                        Text("\(bottle.url.prettyPath()) \(Image(systemName: "link"))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .scaledToFit()
                    }
                    .buttonStyle(.accessoryBar)
                    
                    Spacer()
                    Button(action: {
                        selectedBottleURL = bottle.url
                        isBottleConfigurationViewPresented = true
                    }, label: {
                        Image(systemName: "gear")
                    })
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(bottle.name)\"")
                    
                    Button {
                        bottleURLToDelete = bottle.url
                        isDeletionAlertPresented = true
                    } label: {
                        Image(systemName: "xmark.bin")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .alert(isPresented: $isDeletionAlertPresented) {
                        let bottle = try? Wine.getBottleObject(url: bottleURLToDelete)
                        return Alert(
                            title: .init("Are you sure you want to delete \"\(bottle?.name ?? "Unknown")\"?"),
                            message: .init("This process cannot be undone."),
                            primaryButton: .destructive(.init("Delete")) {
                                do {
                                    guard let bottleURL = bottle?.url else { throw Wine.BottleDoesNotExistError() }
                                    try Wine.deleteBottle(bottleURL: bottleURL)
                                } catch {
                                    Logger.file.error("Unable to delete bottle \(bottle?.name ?? ""): \(error.localizedDescription)")
                                    bottleURLToDelete = .init(filePath: .init())
                                    isDeletionAlertPresented = false
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel")) {
                                bottleURLToDelete = .init(filePath: .init())
                                isDeletionAlertPresented = false
                            }
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        
        .sheet(isPresented: $isBottleConfigurationViewPresented) {
            BottleConfigurationView(bottleURL: $selectedBottleURL, isPresented: $isBottleConfigurationViewPresented)
        }
        /* } else if !Engine.exists {
         Text("Mythic Engine is not installed!")
         .font(.bold(.title)())
         
         Button {
         let app = MythicApp() // FIXME: is this dangerous or just stupid
         app.onboardingPhase = .engineDisclaimer
         app.isOnboardingPresented = true
         } label: {
         Label("Install Mythic Engine", systemImage: "arrow.down.to.line")
         .padding(5)
         }
         .buttonStyle(.borderedProminent)
         } else {
         Text("No bottles can be shown.")
         .font(.bold(.title)())
         
         Button {
         isBottleCreationViewPresented = true
         } label: {
         Label("Create a bottle", systemImage: "plus")
         .padding(5)
         }
         .buttonStyle(.borderedProminent)
         .sheet(isPresented: $isBottleCreationViewPresented) {
         BottleCreationView(isPresented: $isBottleCreationViewPresented)
         }
         }
         */
    }
}

struct BottleConfigurationView: View {
    @Binding var bottleURL: URL
    @Binding var isPresented: Bool
    
    // @State private var bottle: Wine.Bottle?
    
    @State private var configuratorActive: Bool = false
    @State private var registryEditorActive: Bool = false
    
    @State private var isOpenAlertPresented = false
    @State private var openError: Error?
    
    init(bottleURL: Binding<URL>, isPresented: Binding<Bool>) {
        self._bottleURL = bottleURL
        self._isPresented = isPresented
    }
    
    var body: some View {
        if let bottle = try? Wine.getBottleObject(url: self.bottleURL) {
            VStack {
                Text("Configure default settings for \"\(bottle.name)\"") // FIXME: glitch
                    .font(.title)
                
                Form {
                    BottleSettingsView(selectedBottleURL: .constant(bottle.url), withPicker: false)
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
                                    try await Wine.command(arguments: [bottle.url.absoluteString], identifier: "custom_launch_\(url)", waits: true, bottleURL: bottle.url) { _ in }
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
                        try? Wine.launchWinetricks(bottleURL: bottle.url)
                    }
                    .disabled(true)
                    .help("Winetricks GUI support is currently broken.")
                    
                    Button("Launch Configurator") {
                        Task { try await Wine.command(arguments: ["winecfg"], identifier: "winecfg", bottleURL: bottle.url) { _ in } }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            configuratorActive = (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep winecfg.exe | grep -v grep"]))?.isEmpty == false
                            if !configuratorActive { timer.invalidate() }
                        }
                    }
                    .disabled(configuratorActive)
                    
                    Button("Launch Registry Editor") {
                        Task { try await Wine.command(arguments: ["regedit"], identifier: "regedit", bottleURL: bottle.url) { _ in } }
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            registryEditorActive = (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep regedit.exe | grep -v grep"]))?.isEmpty == false // @isaacmarovitz has a better way
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
            .fixedSize()
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Configuring bottle \"\(bottle.name)\""
                    presence.state = "Configuring Bottle"
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
    BottleListView()
}
