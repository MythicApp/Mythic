//
//  WineSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/2/2024.
//

import SwiftUI

struct BottleSettingsView: View {
    
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
            await Wine.getRetinaMode(bottleURL: bottle.url) { result in
                switch result {
                case .success(let success):
                    retinaMode = success
                case .failure(let failure):
                    retinaModeError = failure
                }
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
                get: { /* TODO: add support for different games having different configs under the same bottle
                        switch bottleScope {
                        case .individual:
                        return Wine.individualBottleSettings![game.appName]!.metalHUD
                        case .global: */
                    return Wine.allBottles![selectedBottle]!.settings.metalHUD
                    // }
                }, set: { /* TODO: add support for different games having different configs under the same bottle
                           switch bottleScope {
                           case .individual:
                           <#code#>
                           case .global: */
                    Wine.allBottles![selectedBottle]!.settings.metalHUD = $0
                    // }
                }
            ))
            .disabled(variables.getVariable("booting") == true)
            
            if !modifyingRetinaMode {
                Toggle("Retina Mode", isOn: Binding( // FIXME: make retina mode work!!
                    get: { retinaMode },
                    set: { value in
                        Task(priority: .userInitiated) {
                            modifyingRetinaMode = true
                            do {
                                try await Wine.toggleRetinaMode(bottleURL: Wine.allBottles![selectedBottle]!.url, toggle: value)
                                retinaMode = value
                                Wine.allBottles![selectedBottle]!.settings.retinaMode = value
                                modifyingRetinaMode = false
                            } catch { }
                        }
                    }
                                                   ))
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
