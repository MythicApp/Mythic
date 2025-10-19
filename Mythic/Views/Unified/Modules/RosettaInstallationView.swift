//
//  RosettaInstallationView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/10/2025.
//

import Foundation
import SwiftUI

struct RosettaInstallationView: View {
    @Binding var isPresented: Bool
    @Binding var installationError: Error?
    @Binding var installationComplete: Bool

    @StateObject var viewModel: ViewModel = .init()
    @State private var agreedToSLA: Bool = false

    var body: some View {
        VStack {
            Text("Install Rosetta")
                .font(.title.bold())
                .padding(.bottom)

            Group {
                switch viewModel.currentStage {
                case .disclaimer:
                    DisclaimerView(agreedToSLA: $agreedToSLA)
                case .installer:
                    InstallationView(
                        viewModel: viewModel,
                        isPresented: $isPresented,
                        agreedToSLA: $agreedToSLA,
                        installationError: $installationError,
                        installationComplete: $installationComplete
                    )
                    // THERE IS AN ONCHANGE AND IT DOES NOT FIRE HERE SO I PUT IT INSIDE THE VIEW ☹️☹️
                case .finished:
                    CompletionView(isPresented: $isPresented)
                }
            }

            if viewModel.currentStage != .installer && viewModel.currentStage != .finished {
                // the if statement is a bit primitive, but functional.. the code at those stages are self-sufficient
                Button("Next", systemImage: "arrow.right", action: { viewModel.stepStage() })
                    .clipShape(.capsule)
                    .disabled(!agreedToSLA)
            }
        }
    }
}

extension RosettaInstallationView {
    struct DisclaimerView: View {
        @Binding var agreedToSLA: Bool

        var body: some View {
            Text(
                """
                Rosetta 2 enables a Mac with Apple silicon to use apps
                built for a Mac with an Intel processor.
                
                It's a key component for Windows® game functionality.
                
                To install Rosetta, you must confirm you have read and agreed
                to the terms of the software license agreement.
                """
            )

            Link(
                "A list of Apple SLAs may be found here.",
                destination: .init(string: "https://www.apple.com/legal/sla/")!
            )

            Toggle("I agree to the software license agreement.", isOn: $agreedToSLA.animation())
        }
    }

    struct InstallationView: View {
        @ObservedObject var viewModel: ViewModel
        @Binding var isPresented: Bool
        @Binding var agreedToSLA: Bool
        @Binding var installationError: Error?
        @Binding var installationComplete: Bool

        @State var installationProportion: Double = 0.0
        @State private var isInstallationErrorAlertPresented: Bool = false

        var body: some View {
            ProgressView(value: installationProportion / 100)
                .progressViewStyle(.linear)
                .task {
                    do {
                        try await Rosetta.install(
                            agreeToSLA: agreedToSLA,
                            completion: { progress in
                                Task { @MainActor in
                                    installationProportion = progress
                                }
                            }
                        )
                    } catch {
                        installationError = error
                        isInstallationErrorAlertPresented = true
                    }
                }
                .onChange(of: installationProportion) { _, newValue in
                    // 3-sec cooldown check because the installer spikes to 100 for some reason
                    if newValue == 100.0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if installationProportion == newValue {
                                withAnimation {
                                    installationComplete = true
                                    viewModel.stepStage()
                                }
                            }
                        }
                    }
                }
                .alert(
                    "Unable to install Rosetta 2.",
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
        var body: some View {
            ContentUnavailableView(
                "Rosetta is installed.",
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

extension RosettaInstallationView {
    @Observable final class ViewModel: ObservableObject, StagedFlow {
        init(initialStage stage: Stage = .disclaimer) {
            self.currentStage = stage
        }

        public let stages = Stage.allCases
        enum Stage: CaseIterable {
            case disclaimer
            case installer
            case finished
        }

        var currentStage: Stage
        var currentStageIndex: Int { stages.firstIndex(of: currentStage) ?? 0 }

        func stepStage(by delta: Int = 1) {
            let newIndex = currentStageIndex + delta
            guard stages.indices.contains(newIndex) else { return }
            withAnimation(.bouncy) {
                currentStage = stages[newIndex]
            }
        }
    }
}

#Preview {
    RosettaInstallationView(
        isPresented: .constant(true),
        installationError: .constant(nil),
        installationComplete: .constant(false)
    )
    .padding()
}
