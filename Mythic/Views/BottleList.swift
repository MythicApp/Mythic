//
//  BottleList.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 19/2/2024.
//

import SwiftUI
import OSLog

struct BottleListView: View {
    @State private var isBottleSettingsViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var selectedBottleName: String = .init()
    @State private var bottleNameToDelete: String = .init()
    
    var body: some View {
        if let bottles = Wine.allBottles {
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
                                try await Wine.command(
                                    args: ["winecfg"],
                                    identifier: "winecfg",
                                    bottleURL: bottles[selectedBottleName]!.url
                                )
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
            }
            
            .alert(isPresented: $isDeletionAlertPresented) {
                Alert(
                    title: .init("Are you sure you want to delete \"\(bottleNameToDelete)\"?"),
                    message: .init("This process cannot be undone."),
                    primaryButton: .destructive(.init("Delete")) {
                        do {
                            _ = try Wine.deleteBottle(bottleURL: bottles[bottleNameToDelete]!.url) // FIXME: this is where the crashes will happen
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
        } else if !Libraries.isInstalled() {
            Text("Mythic Engine is not installed!")
                .font(.title)
            Button {
                let app = MythicApp() // FIXME: is this dangerous or just stupid
                app.onboardingChapter = .engineDisclaimer
                app.isFirstLaunch = true
            } label: {
                HStack {
                    Image(systemName: "arrow.down.to.line")
                    Text("Install Mythic Engine")
                }
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
