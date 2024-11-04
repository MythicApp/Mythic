//
//  ContainerSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/2/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct ContainerSettingsView: View {
    // TODO: Add DXVK
    // TODO: FSR 3?
    
    @Binding var selectedContainerURL: URL?
    var withPicker: Bool
    
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var containerScope: Wine.ContainerScope = .individual
    
    @State private var retinaMode: Bool = Wine.defaultContainerSettings.retinaMode
    @State private var modifyingRetinaMode: Bool = true
    @State private var retinaModeError: Error?
    
    @State private var windowsVersion: Wine.WindowsVersion = .win10
    @State private var modifyingWindowsVersion: Bool = true
    @State private var windowsVersionError: Error?

    @State private var rpcBridgeServiceInstalled: Bool = false
    @State private var modifyingRPCBridgeService: Bool = false
    @State private var rpcBridgeServiceError: Error?

    private func fetchRetinaStatus() async {
        withAnimation { modifyingRetinaMode = true }
        do {
            guard let selectedContainerURL = selectedContainerURL else { return } // nothrow
            retinaMode = try await Wine.getRetinaMode(containerURL: selectedContainerURL)
        } catch {
            retinaModeError = error
        }
        withAnimation { modifyingRetinaMode = false }
    }
    
    private func fetchWindowsVersion() async {
        withAnimation { modifyingWindowsVersion = true }
        do {
            guard let selectedContainerURL = selectedContainerURL else { return } // nothrow
            if let fetchedWindowsVersion = try await Wine.getWindowsVersion(containerURL: selectedContainerURL) {
                windowsVersion = fetchedWindowsVersion
            }
        } catch {
            windowsVersionError = error
        }
        withAnimation { modifyingWindowsVersion = false }
    }

    private func fetchRPCBridgeWindowsService() async {
        withAnimation { modifyingRPCBridgeService = true }
        do {
            guard let selectedContainerURL = selectedContainerURL else { return } // nothrow
            rpcBridgeServiceInstalled = try Engine.RPCBridge.windowsServiceInstalled(containerURL: selectedContainerURL)
        } catch {
            rpcBridgeServiceError = error
        }
        withAnimation { modifyingRPCBridgeService = false }
    }

    var body: some View {
        if withPicker {
            if variables.getVariable("booting") != true {
                Picker("Current Container", selection: $selectedContainerURL) {
                    ForEach(Wine.containerObjects) { container in
                        Text(container.name)
                            .tag(container.url.appending(path: "") as URL?) // dirtyfix for picker error -- a little primitive but that's swift's fault
                    }
                }
            } else {
                HStack {
                    Text("Current Container")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        
        if selectedContainerURL != nil {
            if let container = try? Wine.getContainerObject(url: selectedContainerURL!) {
                Toggle("Performance HUD", isOn: Binding(
                    get: { return container.settings.metalHUD },
                    set: { container.settings.metalHUD = $0 }
                ))
                .disabled(variables.getVariable("booting") == true)
                
                if !modifyingRetinaMode, retinaModeError == nil {
                    Toggle("Retina Mode", isOn: Binding(
                        get: { retinaMode },
                        set: { value in
                            Task(priority: .userInitiated) {
                                withAnimation { modifyingRetinaMode = true }
                                await Wine.toggleRetinaMode(containerURL: container.url, toggle: value)
                                retinaMode = value
                                container.settings.retinaMode = value
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
                    get: { return container.settings.msync },
                    set: { container.settings.msync = $0 }
                ))
                .disabled(variables.getVariable("booting") == true)
                
                .task(priority: .high) { await fetchRetinaStatus() }
                .task(priority: .high) { await fetchWindowsVersion() }
                .task(priority: .high) { await fetchRPCBridgeWindowsService() }
                .onChange(of: selectedContainerURL) {
                    Task(priority: .userInitiated) { await fetchRetinaStatus() }
                    Task(priority: .userInitiated) { await fetchWindowsVersion() }
                    Task(priority: .userInitiated) { await fetchRPCBridgeWindowsService() }
                }

                if Engine.RPCBridge.launchAgentInstalled {
                    if !modifyingRPCBridgeService, rpcBridgeServiceError == nil {
                        Toggle("Show activity on Discord", isOn: Binding(
                            get: { rpcBridgeServiceInstalled },
                            set: { value in
                                Task(priority: .userInitiated) {
                                    withAnimation { modifyingRPCBridgeService = true }
                                    
                                    do {
                                        try await Engine.RPCBridge.modifyWindowsService(value ? .install : .uninstall, containerURL: container.url)
                                        rpcBridgeServiceInstalled = value
                                        container.settings.discordRPC = value
                                    } catch {
                                        rpcBridgeServiceError = error
                                    }
                                    
                                    withAnimation { modifyingRPCBridgeService = false }
                                }
                            }
                        ))
                    } else {
                        HStack {
                            Text("Show activity on Discord")
                            Spacer()
                            if rpcBridgeServiceError == nil {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .controlSize(.small)
                                    .help("Discord activity cannot be modified: \(rpcBridgeServiceError?.localizedDescription ?? "Unknown Error.")")
                            }
                        }
                    }
                }

                if !modifyingWindowsVersion, windowsVersionError == nil {
                    Picker("Windows Version", selection: Binding(
                        get: { windowsVersion },
                        set: { value in
                            Task(priority: .userInitiated) {
                                withAnimation { modifyingWindowsVersion = true }
                                await Wine.setWindowsVersion(value, containerURL: container.url)
                                windowsVersion = value
                                container.settings.windowsVersion = value
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
            } else if Wine.containerExists(at: selectedContainerURL!) {
                
            } else {
                
            }
        }
    }
}

#Preview {
    Form {
        ContainerSettingsView(
            selectedContainerURL: .constant(nil),
            withPicker: true
        )
    }
    .formStyle(.grouped)
}
