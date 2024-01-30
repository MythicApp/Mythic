//
//  Wine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import OSLog

struct WineView: View {
    @State private var bottleNameToDelete: String = .init()
    
    @State private var isBottleCreationViewPresented = false
    @State private var isBottleSettingsViewPresented = false
    
    @State private var isDeletionAlertPresented = false
    
    var body: some View {
        HStack {
            Text("All Bottles")
                .font(.title)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        if var bottles = Wine.allBottles {
            List {
                ForEach(Array(bottles.keys), id: \.self) { name in
                    HStack {
                        Text(name)
                        Text(bottles[name]!.url.prettyPath())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .scaledToFit()
                        
                        Spacer()
                        Button(action: {
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
            .padding()
            .onChange(of: bottles) { _, newValue in
                bottles = newValue
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isBottleCreationViewPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a bottle")
                }
            }
            .sheet(isPresented: $isBottleCreationViewPresented) {
                BottleCreationView(isPresented: $isBottleCreationViewPresented)
            }
            .sheet(isPresented: $isBottleSettingsViewPresented) {
                // BottleSettingsView()
            }
            .alert(isPresented: $isDeletionAlertPresented) {
                Alert(
                    title: .init("Are you sure you want to delete \"\(bottleNameToDelete)\"?"),
                    message: .init("This process cannot be undone."),
                    primaryButton: .destructive(.init("Delete")) {
                        do {
                            _ = try Wine.deleteBottle(url: bottles[bottleNameToDelete]!.url) // FIXME: this is where the crashes will happen
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

#Preview {
    WineView()
}
