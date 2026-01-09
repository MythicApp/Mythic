//
//  ContainerListView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import OSLog
import SwordRPC

struct ContainerListView: View {
    @State private var isContainerConfigurationViewPresented = false
    @State private var isDeletionAlertPresented = false
    
    @State private var isContainerCreationViewPresented = false
    
    var body: some View {
        if Engine.isInstalled {
            ForEach(Wine.containerObjects) { container in
                HStack {
                    Text(container.name)

                    Button {
                        NSWorkspace.shared.open(container.url)
                    } label: {
                        Text("\(container.url.prettyPath) \(Image(systemName: "link"))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .scaledToFit()
                    }
                    .buttonStyle(.accessoryBar)

                    Spacer()

                    Button {
                        isContainerConfigurationViewPresented = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .disabled(!Engine.isInstalled)
                    .buttonStyle(.borderless)
                    .help("Modify default settings for \"\(container.name)\"")
                    .sheet(isPresented: $isContainerConfigurationViewPresented) {
                        ContainerConfigurationView(containerURL: .constant(container.url),
                                                   isPresented: $isContainerConfigurationViewPresented)
                    }

                    Button {
                        isDeletionAlertPresented = true
                    } label: {
                        Image(systemName: "xmark.bin")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .alert(isPresented: $isDeletionAlertPresented) {
                        return Alert(
                            title: .init("Are you sure you want to delete \"\(container.name)\"?"),
                            message: .init("This process cannot be undone."),
                            primaryButton: .destructive(.init("Delete")) {
                                do {
                                    try Wine.deleteContainer(containerURL: container.url)
                                } catch {
                                    Logger.file.error("Unable to delete container \(container.name): \(error.localizedDescription)")
                                    isDeletionAlertPresented = false
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel")) {
                                isDeletionAlertPresented = false
                            }
                        )
                    }
                }
            }
        } else if Wine.containerURLs.isEmpty {
            ContentUnavailableView(
                "No containers are initialised. 😢",
                systemImage: "cube.transparent",
                description: Text("""
                    Containers will appear here.
                    You must create a container in order to launch a Windows® game.
                    """)
            )
            
            Button {
                isContainerCreationViewPresented = true
            } label: {
                Label("Create Container", systemImage: "plus")
                    .padding(5)
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $isContainerCreationViewPresented) {
                ContainerCreationView(isPresented: $isContainerCreationViewPresented)
            }
        } else {
            Engine.NotInstalledView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct WinetricksConfigurationView: View {
    @Binding var isPresented: Bool
    let containerURL: URL
    
    // Winetricks verb categories and options
    enum WinetricksCategory: String, CaseIterable, Identifiable {
        case fonts
        case dlls
        case vcredist
        case directx
        case dotnet
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .fonts:
                return String(localized: "Fonts", comment: "Winetricks category for font packages")
            case .dlls:
                return String(localized: "DLLs", comment: "Winetricks category for DLL packages")
            case .vcredist:
                return String(localized: "VC++ Redistributables", comment: "Winetricks category for Visual C++ redistributable packages")
            case .directx:
                return String(localized: "DirectX", comment: "Winetricks category for DirectX packages")
            case .dotnet:
                return String(localized: ".NET", comment: "Winetricks category for .NET framework packages")
            }
        }
        
        var verbs: [WinetricksVerb] {
            switch self {
            case .fonts:
                return [
                    .init(name: "corefonts", descriptionKey: "Microsoft Core Fonts (Arial, Courier New, Times New Roman, etc.)"),
                    .init(name: "tahoma", descriptionKey: "Microsoft Tahoma font"),
                    .init(name: "lucida", descriptionKey: "Microsoft Lucida font"),
                    .init(name: "wenquanyi", descriptionKey: "WenQuanYi CJK font"),
                    .init(name: "fakejapanese", descriptionKey: "Fake Japanese font (for when Takao fonts are unavailable)"),
                    .init(name: "cjkfonts", descriptionKey: "CJK fonts (Chinese, Japanese, Korean)")
                ]
            case .dlls:
                return [
                    .init(name: "mfc42", descriptionKey: "Microsoft Foundation Classes 4.2"),
                    .init(name: "vb6run", descriptionKey: "Visual Basic 6 Runtime"),
                    .init(name: "physx", descriptionKey: "NVIDIA PhysX"),
                    .init(name: "quartz", descriptionKey: "DirectShow runtime (quartz.dll)"),
                    .init(name: "gdiplus", descriptionKey: "Microsoft GDI+"),
                    .init(name: "xact", descriptionKey: "Microsoft XACT (Xbox Audio Cross-platform Tool)")
                ]
            case .vcredist:
                return [
                    .init(name: "vcrun2005", descriptionKey: "Visual C++ 2005 Redistributable"),
                    .init(name: "vcrun2008", descriptionKey: "Visual C++ 2008 Redistributable"),
                    .init(name: "vcrun2010", descriptionKey: "Visual C++ 2010 Redistributable"),
                    .init(name: "vcrun2012", descriptionKey: "Visual C++ 2012 Redistributable"),
                    .init(name: "vcrun2013", descriptionKey: "Visual C++ 2013 Redistributable"),
                    .init(name: "vcrun2015", descriptionKey: "Visual C++ 2015 Redistributable"),
                    .init(name: "vcrun2017", descriptionKey: "Visual C++ 2017 Redistributable"),
                    .init(name: "vcrun2019", descriptionKey: "Visual C++ 2019 Redistributable"),
                    .init(name: "vcrun2022", descriptionKey: "Visual C++ 2022 Redistributable")
                ]
            case .directx:
                return [
                    .init(name: "d3dx9", descriptionKey: "Microsoft d3dx9 (DirectX 9)"),
                    .init(name: "d3dx10", descriptionKey: "Microsoft d3dx10 (DirectX 10)"),
                    .init(name: "d3dx11_43", descriptionKey: "Microsoft d3dx11 (DirectX 11)"),
                    .init(name: "d3dcompiler_43", descriptionKey: "Microsoft D3D Compiler 43"),
                    .init(name: "d3dcompiler_47", descriptionKey: "Microsoft D3D Compiler 47"),
                    .init(name: "dxvk", descriptionKey: "DXVK (Vulkan-based DirectX implementation)")
                ]
            case .dotnet:
                return [
                    .init(name: "dotnet40", descriptionKey: ".NET Framework 4.0"),
                    .init(name: "dotnet45", descriptionKey: ".NET Framework 4.5"),
                    .init(name: "dotnet46", descriptionKey: ".NET Framework 4.6"),
                    .init(name: "dotnet48", descriptionKey: ".NET Framework 4.8"),
                    .init(name: "dotnetdesktop6", descriptionKey: ".NET Desktop Runtime 6"),
                    .init(name: "dotnetdesktop7", descriptionKey: ".NET Desktop Runtime 7")
                ]
            }
        }
    }
    
    struct WinetricksVerb: Identifiable, Hashable {
        let name: String
        let descriptionKey: String
        var id: String { name }
    }
    
    @State private var selectedVerbs: Set<WinetricksVerb> = []
    @State private var selectedCategory: WinetricksCategory = .fonts
    @State private var isInstalling: Bool = false
    @State private var installationProgress: String = ""
    @State private var installationError: Error?
    @State private var isErrorAlertPresented: Bool = false
    @State private var consoleOutput: [String] = []
    @State private var showConsole: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Winetricks")
                .font(.title)
                .padding(.top)
            
            if let container = try? Wine.getContainerObject(at: containerURL) {
                Text("Container: \(container.name)", comment: "Shows the name of the Wine container being configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Main content
            HSplitView {
                // Category list
                List(WinetricksCategory.allCases, selection: $selectedCategory) { category in
                    Text(category.localizedName)
                        .tag(category)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 150, maxWidth: 200)
                
                // Verbs list for selected category
                VStack(alignment: .leading) {
                    Text(selectedCategory.localizedName)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    List(selectedCategory.verbs, selection: $selectedVerbs) { verb in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(verb.name)
                                    .font(.body.monospaced())
                                Text(verb.descriptionKey)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedVerbs.contains(verb) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedVerbs.contains(verb) {
                                selectedVerbs.remove(verb)
                            } else {
                                selectedVerbs.insert(verb)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
                .frame(minWidth: 300)
            }
            .frame(minHeight: 300)
            
            Divider()
            
            // Selected verbs summary
            if !selectedVerbs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected components:", comment: "Label for the list of selected Winetricks components to install")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(selectedVerbs).sorted(by: { $0.name < $1.name })) { verb in
                                HStack(spacing: 4) {
                                    Text(verb.name)
                                        .font(.caption.monospaced())
                                    Button {
                                        selectedVerbs.remove(verb)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.2))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Installation progress
            if isInstalling {
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text(installationProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Console output panel
            if showConsole {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Console Output", comment: "Title for the console output panel")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            let allOutput = consoleOutput.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(allOutput, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .disabled(consoleOutput.isEmpty)
                        .help(String(localized: "Copy all to clipboard", comment: "Tooltip for copying all console output to clipboard"))
                        
                        Button {
                            consoleOutput.removeAll()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(consoleOutput.isEmpty)
                        .help(String(localized: "Clear console", comment: "Tooltip for clearing the console output"))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(consoleOutput.joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .textSelection(.enabled)
                                .id("consoleText")
                        }
                        .frame(height: 150)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .onChange(of: consoleOutput.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo("consoleText", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Buttons
            HStack {
                Button {
                    selectedVerbs.removeAll()
                } label: {
                    Text("Clear Selection", comment: "Button to clear all selected Winetricks components")
                }
                .disabled(selectedVerbs.isEmpty || isInstalling)
                
                if isInstalling || !consoleOutput.isEmpty {
                    Button {
                        withAnimation {
                            showConsole.toggle()
                        }
                    } label: {
                        Label(
                            showConsole
                                ? String(localized: "Hide Console", comment: "Button to hide the console output panel")
                                : String(localized: "Show Console", comment: "Button to show the console output panel"),
                            systemImage: "terminal"
                        )
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .disabled(isInstalling)
                
                Button {
                    installSelectedVerbs()
                } label: {
                    Text("Install Selected", comment: "Button to install selected Winetricks components")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVerbs.isEmpty || isInstalling)
            }
            .padding()
        }
        .frame(minWidth: showConsole ? 650 : 550, minHeight: showConsole ? 600 : 450)
        .alert(isPresented: $isErrorAlertPresented) {
            Alert(
                title: Text("Installation Error", comment: "Title for Winetricks installation error alert"),
                message: Text(installationError?.localizedDescription ?? String(localized: "Unknown error occurred", comment: "Default error message when the specific error is unknown")),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    /// Returns the appropriate color for a console output line
    private func lineColor(for line: String) -> Color {
        // Actual errors from our code
        if line.hasPrefix("!!!") {
            return .red
        }
        // Success messages
        if line.hasPrefix("===") || line.contains("installed successfully") {
            return .green
        }
        // Our info messages
        if line.hasPrefix(">>>") {
            return .blue
        }
        // Default
        return .primary
    }
    
    private func installSelectedVerbs() {
        isInstalling = true
        showConsole = true
        consoleOutput.removeAll()
        installationProgress = String(localized: "Preparing installation...", comment: "Progress message shown when preparing to install Winetricks components")
        
        Task {
            do {
                let verbs = selectedVerbs.map(\.name)
                
                for (index, verb) in verbs.enumerated() {
                    await MainActor.run {
                        installationProgress = String(localized: "Installing \(verb) (\(index + 1)/\(verbs.count))...", comment: "Progress message showing which component is being installed and the progress count")
                        consoleOutput.append(">>> Installing \(verb)...")
                    }
                    
                    try await Wine.runWinetricks(containerURL: containerURL, verb: verb) { output in
                        Task { @MainActor in
                            consoleOutput.append(output)
                        }
                    }
                    
                    await MainActor.run {
                        consoleOutput.append(">>> \(verb) installed successfully.\n")
                    }
                }
                
                await MainActor.run {
                    isInstalling = false
                    installationProgress = ""
                    selectedVerbs.removeAll()
                    consoleOutput.append("=== All components installed successfully! ===")
                }
            } catch {
                await MainActor.run {
                    isInstalling = false
                    consoleOutput.append("!!! ERROR: \(error.localizedDescription)")
                    installationError = error
                    isErrorAlertPresented = true
                }
            }
        }
    }
}

struct ContainerConfigurationView: View {
    @Binding var containerURL: URL
    @Binding var isPresented: Bool

    @State private var isUninstallerActive: Bool = false
    @State private var isConfiguratorActive: Bool = false
    @State private var isRegistryEditorActive: Bool = false

    @State private var isOpenFileImporterPresented: Bool = false
    @State private var isWinetricksConfigurationViewPresented: Bool = false

    @State private var isOpenAlertPresented = false
    @State private var openError: Error?
    
    var body: some View {
        if let container = try? Wine.getContainerObject(at: self.containerURL) {
            VStack {
                Text("Configure \"\(container.name)\"")
                    .font(.title)
                    .padding([.horizontal, .top])

                Form {
                    ContainerSettingsView(
                        selectedContainerURL: .init(
                            get: { containerURL },
                            set: { _ in  }
                        ),
                        withPicker: false
                    )
                    // TODO: Add slider for scaling
                }
                .formStyle(.grouped)
                
                HStack {
                    Button("Open...") {
                        isOpenFileImporterPresented = true
                    }
                    .fileImporter(
                        isPresented: $isOpenFileImporterPresented,
                        allowedContentTypes: [.exe]
                    ) { result in
                        switch result {
                        case .success(let url):
                            Task(priority: .userInitiated) {
                                do {
                                    let process: Process = .init()
                                    process.arguments = [url.path]
                                    Wine.transformProcess(process, containerURL: container.url)
                                    
                                    try process.run()
                                    
                                    process.waitUntilExit()
                                } catch {
                                    openError = error
                                    isOpenAlertPresented = true
                                }
                            }
                        case .failure(let failure):
                            openError = failure
                            isOpenAlertPresented = true
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
                        isWinetricksConfigurationViewPresented = true
                    }
                    .sheet(isPresented: $isWinetricksConfigurationViewPresented) {
                        WinetricksConfigurationView(isPresented: $isWinetricksConfigurationViewPresented, containerURL: container.url)
                    }

                    Button("Install/Uninstall...") {
                        Task {
                            let process: Process = .init()
                            process.arguments = ["uninstaller"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()
                            
                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "uninstaller.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isUninstallerActive = isActive }
                            }
                        }
                    }
                    .disabled(isUninstallerActive)

                    Button("Configure Container...") {
                        let containerURL = container.url

                        Task {
                            let process: Process = .init()
                            process.arguments = ["winecfg"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()

                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "winecfg.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isConfiguratorActive = isActive }
                            }
                        }
                    }
                    .disabled(isConfiguratorActive)
                    
                    Button("Launch Registry Editor") {
                        let containerURL = container.url

                        Task {
                            let process: Process = .init()
                            process.arguments = ["regedit"]
                            Wine.transformProcess(process, containerURL: container.url)
                            
                            try process.run()

                            while let isActive = try? await Wine.tasklist(for: containerURL).contains(where: { $0.imageName == "regedit.exe" }) {
                                try await Task.sleep(for: .seconds(2))
                                await MainActor.run { isRegistryEditorActive = isActive }
                            }
                        }
                    }
                    .disabled(isRegistryEditorActive)
                    
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
                .fixedSize()
            }
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Configuring container \"\(container.name)\""
                    presence.state = "Configuring Container"
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
    Form {
        ContainerListView()
    }
    .formStyle(.grouped)
}
