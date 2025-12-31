//
//  EngineInstallationView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/10/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SwiftUI

// TODO: verify functionality
struct EngineInstallationView: View { // similar to RosettaInstallationView
    @Binding var isPresented: Bool
    @Binding var installationError: Error?
    @Binding var installationComplete: Bool
    
#if DEBUG
    @StateObject var viewModel: ViewModel = .init(initialStage: .installer)
#else
    @ObservedObject var viewModel: ViewModel = .init()
#endif
    
    var body: some View {
        VStack {
            Text("Install Mythic Engine")
                .font(.title.bold())
                .padding(.bottom)
            
            Group {
                switch viewModel.currentStage {
                case .disclaimer:
                    DisclaimerView()
                case .installer:
                    InstallationView(
                        isPresented: $isPresented,
                        viewModel: viewModel,
                        installationError: $installationError,
                        installationComplete: $installationComplete
                    )
                case .finished:
                    CompletionView(isPresented: $isPresented, viewModel: viewModel)
                }
            }
            
            if viewModel.currentStage != .installer && viewModel.currentStage != .finished {
                // the if statement is a bit primitive, but functional.. the code at those stages are self-sufficient
                Button("Next", systemImage: "arrow.right", action: { viewModel.stepStage() })
                    .clipShape(.capsule)
            }
        }
    }
}

extension EngineInstallationView {
    struct DisclaimerView: View {
        var body: some View {
            Text(
                """
                In order to run Windows® games, Mythic must download
                a specialized translation layer.
                
                The download time should take ~10 minutes,
                with an average internet connection.
                """
            )
            .multilineTextAlignment(.center)
        }
    }
    
    struct InstallationView: View {
        @Binding var isPresented: Bool
        @ObservedObject var viewModel: ViewModel
        
        @Binding var installationError: Error?
        @Binding var installationComplete: Bool
        
        @State private var downloadFractionCompleted: Double = 0.0
        @State private var installFractionCompleted: Double = 0.0
        @State private var isInstallationErrorAlertPresented: Bool = false
        
        var body: some View {
            Group {
                if downloadFractionCompleted < 1.0 {
                    Text("Downloading Mythic Engine...")
                    ProgressView(value: downloadFractionCompleted)
                        .progressViewStyle(.linear)
                } else {
                    Text("Installing Mythic Engine...")
                    ProgressView(value: installFractionCompleted)
                        .progressViewStyle(.linear)
                }
            }
            .task {
                guard !Engine.isInstalled else {
                    viewModel.stepStage(); return
                }

                do {
                    guard NSWorkspace.shared.isARM else {
                        throw NSWorkspace.UnsupportedArchitectureError()
                    }

                    for try await installation in Engine.install() {
                        switch installation.stage {
                        case .downloading:
                            downloadFractionCompleted = installation.progress.fractionCompleted
                        case .installing:
                            installFractionCompleted = installation.progress.fractionCompleted
                        }
                    }
                } catch {
                    installationError = error
                    isInstallationErrorAlertPresented = true
                }
            }
            .onChange(of: installFractionCompleted) {
                if $1 >= 1.0 {
                    Task {
                        await MainActor.run {
                            viewModel.stepStage()
                        }
                    }
                }
            }
            .alert(
                "Unable to install Mythic Engine.",
                isPresented: $isInstallationErrorAlertPresented,
                presenting: installationError
            ) { _ in
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
                Text(error.localizedDescription)
            }
        }
    }
    
    struct CompletionView: View {
        @Binding var isPresented: Bool
        @ObservedObject var viewModel: ViewModel
        
        var body: some View {
            ContentUnavailableView(
                "Mythic Engine is installed.",
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

extension EngineInstallationView {
    @Observable final class ViewModel: ObservableObject, StagedFlow {
        init(initialStage stage: Stage = .disclaimer) {
            self.currentStage = stage
        }
        
        public let stages = Stage.allCases
        // swiftlint:disable:next nesting
        enum Stage: CaseIterable {
            case disclaimer
            case installer
            case finished
        }
        
        var currentStage: Stage
    }
}

#Preview {
    EngineInstallationView(
        isPresented: .constant(true),
        installationError: .constant(nil),
        installationComplete: .constant(false)
    )
    .padding()
}
