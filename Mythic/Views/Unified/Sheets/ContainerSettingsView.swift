//
//  ContainerSettings.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 7/2/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

// TODO: refactor
struct ContainerSettingsView: View {
    @Binding var selectedContainerURL: URL?
    var withPicker: Bool
    
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var containerScope: Wine.ContainerScope = .individual
    
    @State private var retinaMode: Bool = Wine.ContainerSettings().retinaMode
    @State private var modifyingRetinaMode: Bool = true
    @State private var retinaModeError: Error?

    @State private var isDXVKDisclaimerPresented: Bool = false
    @State private var modifyingDXVK: Bool = false
    @State private var dxvkError: Error?

    @State private var windowsVersion: Wine.WindowsVersion = Wine.ContainerSettings().windowsVersion
    @State private var modifyingWindowsVersion: Bool = true
    @State private var windowsVersionError: Error?
    
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
                Group {
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
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
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

                    Toggle("Advanced Vector Extensions (AVX2)", isOn: Binding(
                        get: { container.settings.avx2 },
                        set: { container.settings.avx2 = $0 }
                    ))
                    .disabled({
                        if #available(macOS 15.0, *) {
                            return false
                        }

                        return true
                    }())
                    .help({
                        if #available(macOS 15.0, *) {
                            return ""
                        }

                        return "AVX2 is only supported on macOS Sequoia (15) or later."
                    }())

                    if !modifyingDXVK, dxvkError == nil {
                        Toggle("DXVK", isOn: Binding(
                            get: { container.settings.dxvk },
                            set: { newValue in
                                isDXVKDisclaimerPresented = true
                            }
                        ))
                        .alert(isPresented: $isDXVKDisclaimerPresented) {
                            .init(
                                title: .init("Quit games running in this container?"),
                                message: .init("""
                                To toggle DXVK, Mythic must quit all games currently running in this container.
                                Additionally, D3DMetal will be disabled.
                                
                                Toggling DXVK may impact compatibility positively or negatively.
                                """),
                                primaryButton: .default(.init("OK")) {
                                    Task(priority: .userInitiated) {
                                        do {
                                            withAnimation { modifyingDXVK = true }

                                            try Wine.killAll(containerURLs: [container.url])

                                            // x64
                                            try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/system32/d3d10core.dll"))
                                            try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/system32/d3d11.dll"))

                                            // x32
                                            try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/syswow64/d3d10core.dll"))
                                            try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/syswow64/d3d11.dll"))

                                            if container.settings.dxvk {
                                                try await Wine.command(
                                                    arguments: ["wineboot", "-u"],
                                                    identifier: "dxvkRestore",
                                                    containerURL: container.url,
                                                    completion: { _ in }
                                                )
                                            } else {
                                                // x64
                                                try files.forceCopyItem(
                                                    at: Engine.directory.appending(path: "DXVK/x64/d3d10core.dll"),
                                                    to: container.url.appending(path: "drive_c/windows/system32")
                                                )
                                                try files.forceCopyItem(
                                                    at: Engine.directory.appending(path: "DXVK/x64/d3d11.dll"),
                                                    to: container.url.appending(path: "drive_c/windows/system32")
                                                )

                                                // x32
                                                try files.forceCopyItem(
                                                    at: Engine.directory.appending(path: "DXVK/x32/d3d10core.dll"),
                                                    to: container.url.appending(path: "drive_c/windows/syswow64")
                                                )
                                                try files.forceCopyItem(
                                                    at: Engine.directory.appending(path: "DXVK/x32/d3d11.dll"),
                                                    to: container.url.appending(path: "drive_c/windows/syswow64")
                                                )
                                            }

                                            container.settings.dxvk.toggle()
                                            withAnimation { modifyingDXVK = false }
                                        } catch {
                                            dxvkError = error
                                        }
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    } else {
                        HStack {
                            Text("DXVK")
                            Spacer()
                            if dxvkError == nil {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .controlSize(.small)
                                    .help("DXVK cannot be modified: \(dxvkError?.localizedDescription ?? "Unknown Error.")")
                            }
                        }
                    }

                    Toggle("Asynchronous DXVK", isOn: Binding(
                        get: { container.settings.dxvkAsync },
                        set: { container.settings.dxvkAsync = $0 }
                    ))
                    .disabled(!container.settings.dxvk || modifyingDXVK)

                    if !modifyingWindowsVersion, windowsVersionError == nil {
                        Picker("Windows Version", selection: Binding(
                            get: { windowsVersion },
                            set: { value in
                                Task(priority: .userInitiated) {
                                    withAnimation { modifyingWindowsVersion = true }
                                    await Wine.setWindowsVersion(containerURL: container.url, version: value)
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
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .controlSize(.small)
                                    .help("Windows version cannot be modified: \(retinaModeError?.localizedDescription ?? "Unknown Error.")")
                            }
                        }
                    }
                }
                .task(priority: .high) { await fetchRetinaStatus() }
                .task(priority: .high) { await fetchWindowsVersion() }
                .onChange(of: selectedContainerURL) {
                    Task(priority: .userInitiated) { await fetchRetinaStatus() }
                    Task(priority: .userInitiated) { await fetchWindowsVersion() }
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
            selectedContainerURL: Binding(
                get: { Wine.containerURLs.first },
                set: { _ in }
            ),
            withPicker: true
        )
    }
    .formStyle(.grouped)
}
