//
//  BottleSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/2/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct BottleSettingsView: View {
    // TODO: Add DXVK
    // TODO: FSR 3?
    
    @Binding var selectedBottle: String
    var withPicker: Bool
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var bottleScope: Wine.BottleScope = .individual
    
    @State private var retinaMode: Bool = Wine.defaultBottleSettings.retinaMode
    @State private var modifyingRetinaMode: Bool = true
    @State private var retinaModeError: Error?
    
    private func fetchRetinaStatus() async {
        modifyingRetinaMode = true
        if let bottle = Wine.allBottles?[selectedBottle] {
            do {
                retinaMode = try await Wine.getRetinaMode(bottleURL: bottle.url)
            } catch {
                retinaModeError = error
            }
        }
        modifyingRetinaMode = false
    }
    
    var body: some View {
        if withPicker {
            if variables.getVariable("booting") != true {
                /* TODO: add support for different games having different configs under the same bottle
                 Picker("Bottle Scope", selection: $bottleScope) {
                 ForEach(type(of: bottleScope).allCases, id: \.self) {
                 Text($0.rawValue)
                 }
                 }
                 .pickerStyle(InlinePickerStyle())
                 */
                
                Picker("Current Bottle", selection: $selectedBottle) { // also remember to make that the bottle it launches with
                    ForEach(Array((Wine.allBottles ?? .init()).keys), id: \.self) { name in
                        Text(name)
                    }
                }
                .disabled(((Wine.allBottles?.contains { $0.key == "Default" }) == nil))
            } else {
                HStack {
                    Text("Current bottle:")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        if Wine.allBottles?[selectedBottle] != nil {
            Toggle("Performance HUD", isOn: Binding(
                get: { return Wine.allBottles![selectedBottle]!.settings.metalHUD },
                set: { Wine.allBottles![selectedBottle]!.settings.metalHUD = $0 }
            ))
            .disabled(variables.getVariable("booting") == true)
            
            if !modifyingRetinaMode {
                Toggle("Retina Mode", isOn: Binding(
                    get: { retinaMode },
                    set: { value in
                        Task(priority: .userInitiated) {
                            withAnimation { modifyingRetinaMode = true }
                            do {
                                try await Wine.toggleRetinaMode(bottleURL: Wine.allBottles![selectedBottle]!.url, toggle: value)
                                retinaMode = value
                                Wine.allBottles![selectedBottle]!.settings.retinaMode = value
                                withAnimation { modifyingRetinaMode = false }
                            } catch {
                                
                            }
                        }
                    }
                                                   )
                )
                .disabled(variables.getVariable("booting") == true)
                .disabled(modifyingRetinaMode)
            } else {
                HStack {
                    Text("Retina Mode")
                    Spacer()
                    if retinaModeError == nil {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .controlSize(.small)
                            .help("Retina Mode cannot be modified: \(retinaModeError?.localizedDescription ?? "Unknown Error.")")
                    }
                }
            }
            
            Toggle("Enhanced Sync (MSync)", isOn: Binding(
                get: { return Wine.allBottles![selectedBottle]!.settings.msync },
                set: { Wine.allBottles![selectedBottle]!.settings.msync = $0 }
            ))
            .disabled(variables.getVariable("booting") == true)
            .task(priority: .userInitiated) { await fetchRetinaStatus() }
            .onChange(of: selectedBottle) {
                Task(priority: .userInitiated) { await fetchRetinaStatus() }
            }
        }
    }
}

#Preview {
    Form {
        BottleSettingsView(
            selectedBottle: .constant("Default"),
            withPicker: true
        )
    }
    .formStyle(.grouped)
}
