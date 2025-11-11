//
//  ContainerSettings.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 7/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct ContainerSettingsView: View {
    @Binding var selectedContainerURL: URL?
    var withPicker: Bool

    @ObservedObject private var variables: VariableManager = .shared

    @State private var containerScope: Wine.Container.Scope = .individual

    @State private var retinaMode: Bool = Wine.Container.Settings().retinaMode
    @State private var modifyingRetinaMode: Bool = false
    @State private var retinaModeSuccess: Bool?

    @State private var isDXVKDisclaimerPresented: Bool = false
    @State private var modifyingDXVK: Bool = false
    @State private var dxvkSuccess: Bool?

    @State private var windowsVersion: Wine.WindowsVersion = Wine.Container.Settings().windowsVersion
    @State private var modifyingWindowsVersion: Bool = false
    @State private var windowsVersionSuccess: Bool?

    private func fetchRetinaStatus() async {
        guard let selectedContainerURL = selectedContainerURL else { return }
        do {
            retinaMode = try await Wine.getRetinaMode(containerURL: selectedContainerURL)
        } catch {
            retinaModeSuccess = false
        }
    }

    private func fetchWindowsVersion() async {
        guard let selectedContainerURL = selectedContainerURL else { return }
        do {
            if let fetchedWindowsVersion = try await Wine.getWindowsVersion(containerURL: selectedContainerURL) {
                windowsVersion = fetchedWindowsVersion
            }
        } catch {
            windowsVersionSuccess = false
        }
    }

    var body: some View {
        if withPicker {
            if variables.getVariable("booting") != true {
                Picker("Current Container", selection: $selectedContainerURL) {
                    ForEach(Wine.containerObjects) { container in
                        Text(container.name)
                            .tag(container.url.appending(path: "") as URL?)
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

        if let selectedContainerURL = selectedContainerURL,
           let container = try? Wine.getContainerObject(url: selectedContainerURL) {
            Group {
                Toggle("Performance HUD", isOn: Binding(
                    get: { container.settings.metalHUD },
                    set: { container.settings.metalHUD = $0 }
                ))
                .disabled(variables.getVariable("booting") == true)

                Toggle("Retina Mode", isOn: $retinaMode)
                    .disabled(variables.getVariable("booting") == true)
                    .withOperationStatus(
                        operating: $modifyingRetinaMode,
                        successful: $retinaModeSuccess,
                        observing: $retinaMode,
                        placement: .leading
                    ) {
                        await Wine.toggleRetinaMode(containerURL: container.url, toggle: retinaMode)
                        container.settings.retinaMode = retinaMode
                        retinaModeSuccess = true
                    }

                Toggle("Enhanced Sync (MSync)", isOn: Binding(
                    get: { container.settings.msync },
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
                    guard #unavailable(macOS 15.0) else { return "" }
                    return "AVX2 is only supported on macOS Sequoia (15) or later."
                }())

                Toggle("DXVK", isOn: Binding(
                    get: { container.settings.dxvk },
                    set: { _ in
                        isDXVKDisclaimerPresented = true
                    }
                ))
                .withOperationStatus(
                    operating: $modifyingDXVK,
                    successful: $dxvkSuccess,
                    observing: .constant(false),
                    placement: .leading,
                    action: {} // handled by alert presentation
                )
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
                                modifyingDXVK = true
                                do {
                                    try Wine.killAll(containerURLs: [container.url])

                                    // x64
                                    try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/system32/d3d10core.dll"))
                                    try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/system32/d3d11.dll"))

                                    // x32
                                    try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/syswow64/d3d10core.dll"))
                                    try files.removeItemIfExists(at: container.url.appending(path: "drive_c/windows/syswow64/d3d11.dll"))

                                    if container.settings.dxvk {
                                        try await Wine.execute(
                                            arguments: ["wineboot", "-u"],
                                            containerURL: container.url
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
                                    dxvkSuccess = true
                                } catch {
                                    dxvkSuccess = false
                                }
                                modifyingDXVK = false
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }

                Toggle("Asynchronous DXVK", isOn: Binding(
                    get: { container.settings.dxvkAsync },
                    set: { container.settings.dxvkAsync = $0 }
                ))
                .disabled(!container.settings.dxvk || modifyingDXVK)

                Picker("Windows Version", selection: $windowsVersion) {
                    ForEach(Wine.WindowsVersion.allCases, id: \.self) { version in
                        Text("Windows® \(version.rawValue)").tag(version)
                    }
                }
                .withOperationStatus(
                    operating: $modifyingWindowsVersion,
                    successful: $windowsVersionSuccess,
                    observing: $windowsVersion,
                    placement: .leading
                ) {
                    await Wine.setWindowsVersion(containerURL: container.url, version: windowsVersion)
                    container.settings.windowsVersion = windowsVersion
                    windowsVersionSuccess = true
                }
            }
            .disabled(!Engine.isInstalled)
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
