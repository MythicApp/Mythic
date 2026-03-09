//
//  D3DMetalInstallationView.swift
//  Mythic
//
//  Created by vapidinfinity on 1/1/2026.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SwiftUI

struct D3DMetalInstallationView: View {
    @Binding var isPresented: Bool
    @Binding var installationError: Error?
    @Binding var installationComplete: Bool
    
#if DEBUG
    @StateObject var viewModel: ViewModel = .init(initialStage: .downloadInstructions)
#else
    @ObservedObject var viewModel: ViewModel = .init()
#endif
    
    @State private var isEngineRequiredErrorPresented: Bool = false
    @State private var isCancellationAlertPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("Install D3DMetal")
                .font(.title.bold())
                .padding(.bottom)
            
            Group {
                switch viewModel.currentStage {
                case .downloadInstructions:
                    DownloadInstructionsView(isPresented: $isPresented, viewModel: viewModel)
                case .installInstructions:
                    InstallationInstructionsView(
                        isPresented: $isPresented,
                        viewModel: viewModel,
                        installationError: $installationError,
                        installationComplete: $installationComplete
                    )
                case .finished:
                    CompletionView(isPresented: $isPresented)
                }
            }
            .task {
                if !Engine.isInstalled {
                    installationError = Engine.NotInstalledError()
                    isEngineRequiredErrorPresented = true
                }
            }
            // FIXME: make properly lol
            .alert("Mythic Engine is required in order to install D3DMetal.",
                   isPresented: $isEngineRequiredErrorPresented,
                   presenting: $installationError) { _ in
                if #available(macOS 26.0, *) {
                    Button("OK", role: .close) {
                        isPresented = false
                    }
                } else {
                    Button("OK", role: .cancel) {
                        isPresented = false
                    }
                }
            } message: { error in
                Text(error.wrappedValue?.localizedDescription ?? "Unknown error.")
            }
            
            if ![.installInstructions, .finished].contains(viewModel.currentStage) {
                // the if statement is a bit primitive, but functional.. the code at those stages are self-sufficient
                HStack {
                    Button("Skip", systemImage: "xmark") {
                        isCancellationAlertPresented = true
                    }
                    .clipShape(.capsule)
                    .alert("Skip D3DMetal installation?",
                           isPresented: $isCancellationAlertPresented) {
                        // FIXME: ambiguous?
                        Button("Skip", role: .destructive) {
                            isPresented = false
                        }
                        
                        Button("Continue", role: .cancel, action: {})
                    } message: {
                        Text("""
                        Compatibility with certain games may be impacted.
                        You may install it later in Mythic Settings.
                        """)
                    }
                    
                    Button("Next", systemImage: "arrow.right", action: { viewModel.stepStage() })
                        .clipShape(.capsule)
                }
            }
        }
    }
}

extension D3DMetalInstallationView {
    struct DownloadInstructionsView: View {
        @Binding var isPresented: Bool
        @ObservedObject var viewModel: ViewModel
        
        @State private var latestEngineRelease: Engine.UpdateCatalog.Release?
        
        @State private var isEngineReleaseRetrievalErrorPresented: Bool = false
        @State private var engineReleaseRetrievalError: Error?
        
        var body: some View {
            // TODO: !! ADD VISUAL AID (diagram, GIF, video/embed)
            Text("""
                To achieve the full functionality of Mythic Engine, D3DMetal, a component of Apple's Game Porting Toolkit development tool, is recommended for installation.
                
                Due to licensing restrictions, this installation must be completed by the user.
                """)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom)
            
            HStack {
                Text("Begin by clicking the highlighted button to visit the Game Porting Toolkit download page.")
                
                Button("Link",
                       systemImage: "link",
                       action: { NSWorkspace.shared.open(.init(string: "https://developer.apple.com/download/all/?q=game%20porting%20toolkit")!) }
                )
                .buttonStyle(.borderedProminent)
                .clipShape(.capsule)
            }
            .padding(.bottom)
            
            Divider()
            
            Text("""
                1. Sign into your Apple account, if necessary.
                
                2. Navigate to 'Game Porting Toolkit \(latestEngineRelease?.targetGPTKVersion.prettyRelaxedString ?? "(...)")'.
                
                3. Download it by expanding the [View Details 􀆈] dropdown, and clicking the blue text with the 􀁸 icon.
                
                Once you've downloaded it, click [􀄫 Next].
                """)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task { @MainActor in
                guard (try? Engine.retrieveInstallationProperties().isD3DMetalInstalled) != true else {
                    viewModel.currentStage = .finished; return
                }
                
                do {
                    self.latestEngineRelease = try await Engine.getLatestCompatibleRelease()
                } catch {
                    engineReleaseRetrievalError = error
                    isEngineReleaseRetrievalErrorPresented = true
                }
            }
            .alert("Unable to retrieve the latest Mythic Engine release.",
                   isPresented: $isEngineReleaseRetrievalErrorPresented,
                   presenting: engineReleaseRetrievalError) { _ in
                if #available(macOS 26.0, *) {
                    Button("OK", role: .close) {
                        isPresented = false
                    }
                } else {
                    Button("OK", role: .cancel) {
                        isPresented = false
                    }
                }
            } message: { error in
                Text(error?.localizedDescription ?? "Unknown Error.")
            }
        }
    }
    
    struct InstallationInstructionsView: View {
        @Binding var isPresented: Bool
        @ObservedObject var viewModel: ViewModel
        
        @Binding var installationError: Error?
        @Binding var installationComplete: Bool
        
        @State private var isHoveringOverDragTarget: Bool = false
        @State private var isInstallationFileImporterPresented: Bool = false
        
        @State private var isInstallationErrorAlertPresented: Bool = false
        
        var body: some View {
            Text("""
                4. Locate and open the downloaded file named similarly to **Game_Porting_Toolkit_x.dmg** using Finder.
                
                5. Within the Game Porting Toolkit disk image, locate and open the file named similarly to **Evaluation environment for Windows games x**.dmg.
                
                6. Ensure you **read and evaluate the license agreement presented to you** upon opening it.
                
                7. Press the [􀈕 Browse...] button below, and locate **'Evaluation Environment for Windows Games'** in the sidebar of the Finder window that appears.
                
                8. Select the **'redist'** folder, and select [Open] in the bottom right of the Finder window.
                """)
            .padding(.bottom)
            .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Button("Previous", systemImage: "arrow.left") {
                    viewModel.stepStage(by: -1)
                }
                .clipShape(.capsule)
                
                Button("Browse...", systemImage: "folder") {
                    isInstallationFileImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.capsule)
                .fileImporter(
                    isPresented: $isInstallationFileImporterPresented,
                    allowedContentTypes: [.folder]
                ) { result in
                    switch result {
                    case .success(let success):
                        do {
                            try D3DMetal.install(from: success)
                            viewModel.stepStage()
                        } catch {
                            installationError = error
                            isInstallationErrorAlertPresented = true
                        }
                    case .failure(let failure):
                        installationError = failure
                        isInstallationErrorAlertPresented = true
                    }
                }
                .alert("Unable to install D3DMetal.",
                       isPresented: $isInstallationErrorAlertPresented,
                       presenting: installationError) { _ in
                    if #available(macOS 26.0, *) {
                        Button("OK", role: .close) {
                            isPresented = false
                        }
                    } else {
                        Button("OK", role: .cancel) {
                            isPresented = false
                        }
                    }
                } message: { error in
                    Text(error?.localizedDescription ?? "Unknown error.")
                }
            }
        }
    }
    
    struct CompletionView: View {
        @Binding var isPresented: Bool
        
        var body: some View {
            ContentUnavailableView(
                "D3DMetal is installed.",
                systemImage: "checkmark"
            )
            .task {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isPresented = false
                }
            }
        }
    }
}

extension D3DMetalInstallationView {
    @Observable final class ViewModel: ObservableObject, StagedFlow {
        init(initialStage stage: Stage = .downloadInstructions) {
            self.currentStage = stage
        }
        
        public let stages = Stage.allCases
        // swiftlint:disable:next nesting
        enum Stage: CaseIterable {
            case downloadInstructions
            case installInstructions
            case finished
        }
        
        var currentStage: Stage
    }
}

#Preview {
    D3DMetalInstallationView(
        isPresented: .constant(true),
        installationError: .constant(nil),
        installationComplete: .constant(false)
    )
    .padding()
    .fixedSize()
}
