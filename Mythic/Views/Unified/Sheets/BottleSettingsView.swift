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
    
    @Binding var selectedBottleURL: URL?
    var withPicker: Bool
    
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var bottleScope: Wine.BottleScope = .individual
    
    @State private var retinaMode: Bool = Wine.defaultBottleSettings.retinaMode
    @State private var modifyingRetinaMode: Bool = true
    @State private var retinaModeError: Error?
    
    @State private var windowsVersion: Wine.WindowsVersion = .win10
    @State private var modifyingWindowsVersion: Bool = true
    @State private var windowsVersionError: Error?
    
    private func fetchRetinaStatus() async {
        withAnimation { modifyingRetinaMode = true }
        do {
            guard let selectedBottleURL = selectedBottleURL else { return } // nothrow
            retinaMode = try await Wine.getRetinaMode(bottleURL: selectedBottleURL)
        } catch {
            retinaModeError = error
        }
        withAnimation { modifyingRetinaMode = false }
    }
    
    private func fetchWindowsVersion() async {
        withAnimation { modifyingWindowsVersion = true }
        do {
            guard let selectedBottleURL = selectedBottleURL else { return } // nothrow
            if let fetchedWindowsVersion = try await Wine.getWindowsVersion(bottleURL: selectedBottleURL) {
                windowsVersion = fetchedWindowsVersion
            }
        } catch {
            windowsVersionError = error
        }
        withAnimation { modifyingWindowsVersion = false }
    }
    
    var body: some View {
        if withPicker {
            if variables.getVariable("booting") != true {
                Picker("Current Bottle", selection: $selectedBottleURL) {
                    ForEach(Wine.bottleObjects) { bottle in
                        Text(bottle.name)
                            .tag(bottle.url)
                    }
                }
            } else {
                HStack {
                    Text("Current Bottle")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        
        if selectedBottleURL != nil {
            if let bottle = try? Wine.getBottleObject(url: selectedBottleURL!) {
                Toggle("Performance HUD", isOn: Binding(
                    get: { return bottle.settings.metalHUD },
                    set: { bottle.settings.metalHUD = $0 }
                ))
                .disabled(variables.getVariable("booting") == true)
                
                if !modifyingRetinaMode {
                    Toggle("Retina Mode", isOn: Binding(
                        get: { retinaMode },
                        set: { value in
                            Task(priority: .userInitiated) {
                                withAnimation { modifyingRetinaMode = true }
                                await Wine.toggleRetinaMode(bottleURL: bottle.url, toggle: value)
                                retinaMode = value
                                bottle.settings.retinaMode = value
                                withAnimation { modifyingRetinaMode = false }
                            }
                        }
                    ))
                    .disabled(variables.getVariable("booting") == true)
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
                    get: { return bottle.settings.msync },
                    set: { bottle.settings.msync = $0 }
                ))
                .disabled(variables.getVariable("booting") == true)
                
                .task(priority: .high) { await fetchRetinaStatus() }
                .task(priority: .high) { await fetchWindowsVersion() }
                .onChange(of: selectedBottleURL) {
                    Task(priority: .userInitiated) { await fetchRetinaStatus() }
                    Task(priority: .userInitiated) { await fetchWindowsVersion() }
                }
                
                if !modifyingWindowsVersion {
                    Picker("Windows Version", selection: Binding(
                        get: { windowsVersion },
                        set: { value in
                            Task(priority: .userInitiated) {
                                withAnimation { modifyingWindowsVersion = true }
                                await Wine.setWindowsVersion(value, bottleURL: bottle.url)
                                windowsVersion = value
                                bottle.settings.windowsVersion = value
                                withAnimation { modifyingWindowsVersion = false }
                            }
                        }
                    )) {
                        ForEach(Wine.WindowsVersion.allCases, id: \.self) { version in
                            Text("Windows® \(version.rawValue)").tag(version)
                        }
                    }
                } else {
                    HStack {
                        Text("Windows Version")
                        Spacer()
                        if windowsVersionError == nil {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .controlSize(.small)
                                .help("Windows version cannot be modified: \(retinaModeError?.localizedDescription ?? "Unknown Error.")")
                        }
                    }
                }
            } else if Wine.bottleExists(bottleURL: selectedBottleURL!) {
                
            } else {
                
            }
        }
    }
}

#Preview {
    Form {
        BottleSettingsView(
            selectedBottleURL: .constant(nil),
            withPicker: true
        )
    }
    .formStyle(.grouped)
}
