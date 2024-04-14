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
    @State private var isBottleSettingsViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var selectedBottleName: String = .init()
    @State private var bottleNameToDelete: String = .init()
    
    @State private var configuratorActive: Bool = false
    
    var body: some View {
        if let bottles = Wine.allBottles, !bottles.isEmpty {
            Form {
                ForEach(Array(bottles.keys), id: \.self) { name in
                    HStack {
                        Text(name)
                        Text(bottles[name]!.url.prettyPath())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .scaledToFit()
                        
                        Spacer()
                        Button(action: {
                            selectedBottleName = name
                            isBottleSettingsViewPresented = true
                        }, label: {
                            Image(systemName: "gear")
                        })
                        .buttonStyle(.borderless)
                        .help("Modify default settings for \"\(name)\"")
                        
                        Button(action: {
                            if name != "Default" {
                                bottleNameToDelete = name
                                isDeletionAlertPresented = true
                            }
                        }, label: {
                            Image(systemName: "xmark.bin")
                        })
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .opacity(name == "Default" ? 0.5 : 1)
                        .help(name == "Default" ? "You can't delete the default bottle." : "Delete \"\(name)\"")
                        .alert(isPresented: $isDeletionAlertPresented) {
                            Alert(
                                title: .init("Are you sure you want to delete \"\(bottleNameToDelete)\"?"),
                                message: .init("This process cannot be undone."),
                                primaryButton: .destructive(.init("Delete")) {
                                    do {
                                        try Wine.deleteBottle(bottleURL: bottles[bottleNameToDelete]!.url) // FIXME: may produce crashes
                                    } catch {
                                        Logger.file.error("Unable to delete bottle \(bottleNameToDelete): \(error.localizedDescription)")
                                        bottleNameToDelete = .init()
                                        isDeletionAlertPresented = false
                                    }
                                },
                                secondaryButton: .cancel(.init("Cancel")) {
                                    bottleNameToDelete = .init()
                                    isDeletionAlertPresented = false
                                }
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            .sheet(isPresented: $isBottleSettingsViewPresented) {
                VStack {
                    Text("Configure default settings for \"\(selectedBottleName)\"") // FIXME: glitch
                        .font(.title)
                    
                    Form {
                        BottleSettingsView(selectedBottle: $selectedBottleName, withPicker: false)
                        // TODO: Add slider for scaling
                        // TODO: Add slider for winver
                    }
                    .formStyle(.grouped)
                    
                    HStack {
                        Spacer()
                        
                        Button("Launch Winetricks") {
                            try? Wine.launchWinetricks(prefix: bottles[selectedBottleName]!.url)
                        }
                        
                        Button("Launch Configurator") {
                            Task {
                                try await Wine.command(arguments: ["winecfg"], identifier: "winecfg", bottleURL: bottles[selectedBottleName]!.url) {_, _ in }
                            }
                        }
                        .disabled(configuratorActive)
                        .task(priority: .background) { // FIXME: Will keep going even when view loses focus
                            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _/*timer*/ in
                                configuratorActive = (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep winecfg | grep -v grep"]))?.isEmpty == false
                            }
                        }
                        
                        Button("Close") {
                            isBottleSettingsViewPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .fixedSize()
                .task(priority: .background) {
                    discordRPC.setPresence({
                        var presence: RichPresence = .init()
                        presence.details = "Configuring bottle \"\(selectedBottleName)\""
                        presence.state = "Configuring Bottle"
                        presence.timestamps.start = .now
                        presence.assets.largeImage = "macos_512x512_2x"
                        
                        return presence
                    }())
                }
            }
        } else if !Libraries.isInstalled() {
            Text("Mythic Engine is not installed!")
                .font(.bold(.title)())
            
            Button {
                let app = MythicApp() // FIXME: is this dangerous or just stupid
                app.onboardingChapter = .engineDisclaimer
                app.isFirstLaunch = true
            } label: {
                Label("Install Mythic Engine", systemImage: "arrow.down.to.line")
                    .padding(5)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .symbolEffect(.pulse)
                .help("Unable to fetch bottles.")
        }
    }
}

#Preview {
    BottleListView()
}
