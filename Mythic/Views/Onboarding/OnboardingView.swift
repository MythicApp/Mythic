//
//  OnboardingView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/10/2025.
//

// Onboarding — Revision III
// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import ColorfulX
import SwordRPC

struct OnboardingView: View {
    @StateObject var viewModel: ViewModel = .init()

    @AppStorage("isOnboardingPresented") var isOnboardingPresented: Bool = true
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject var epicWebAuthViewModel: EpicWebAuthViewModel = .shared

    @State private var colorfulViewColors: [Color] = [
        .init(hex: "#7541FF"),
        .init(hex: "#5412FF"),
        Color(nsColor: .windowBackgroundColor)
    ]
    @State private var onboardingError: Error?

    @State private var isHoveringOverProgressView: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    HStack {
                        ForEach(viewModel.stages) { stage in
                            if viewModel.currentStage > stage {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            } else if viewModel.currentStage == stage {
                                Image(systemName: "circle")
                                    .symbolVariant(.fill)
                                Text(stage.rawValue)
                            } else if viewModel.currentStage < stage {
                                Image(systemName: "circle")
                            }
                        }
                    }
                    .padding(.top)
                    .onHover { hovering in
                        withAnimation {
                            isHoveringOverProgressView = hovering
                        }
                    }

                    if isHoveringOverProgressView {
                        Text("\(viewModel.fractionCompleted.formatted(.percent.precision(.fractionLength(0)))) complete")
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                VStack {
                    Group {
                        switch viewModel.currentStage {
                        case .welcome:
                            WelcomeStage()
                        case .signin:
                            SignInStage()
                                .fixedSize()
                                .onChange(of: epicWebAuthViewModel.signInSuccess) { _, success in
                                    // FIXME: since there's only epic, we can auto-skip after signin is a success
                                    // TODO: add more cases as storefronts populate
                                    if success {
                                        viewModel.stepStage()
                                    }
                                }
                        case .greetings:
                            GreetingStage()
                                .task { @MainActor in
                                    if !Legendary.isSignedIn { // TODO: add more cases as storefronts populate
                                        viewModel.stepStage()
                                    }
                                }
                        case .rosetta:
                            RosettaStage(
                                isPresented: .init( // Handles presentation within onboarding
                                    get: { true },
                                    set: { newValue in
                                        if !newValue {
                                            viewModel.stepStage()
                                        }
                                    }
                                )
                            )
                        case .engine:
                            EngineStage(
                                isPresented: .init( // Handles presentation within onboarding
                                    get: { true },
                                    set: { newValue in
                                        if !newValue {
                                            viewModel.stepStage()
                                        }
                                    }
                                )
                            )
                        case .defaultContainerSetup:
                            DefaultContainerSetupStage(
                                isPresented: .init( // Handles presentation within onboarding
                                    get: { true },
                                    set: { newValue in
                                        if !newValue {
                                            viewModel.stepStage()
                                        }
                                    }
                                )
                            )
                        case .finished:
                            FinishedStage()
                        }
                    }
                    .frame(width: geometry.size.width * 0.75)
                    .padding(.horizontal)

                    if !(viewModel.currentStage == .rosetta || viewModel.currentStage == .engine || viewModel.currentStage == .defaultContainerSetup) {
                        // the if statement is a bit primitive, but functional.. the code at those stages are self-sufficient
                        HStack {
                            if onboardingError != nil {
                                Button(String(describing: "Restart"), systemImage: "arrow.trianglehead.clockwise", action: { viewModel.reset() })
                                    .clipShape(.capsule)
                            } else {
                                Button("Next", systemImage: "arrow.right") {
                                    if viewModel.currentStage < .finished {
                                        viewModel.stepStage()
                                    } else {
                                        withAnimation {
                                            isOnboardingPresented = false
                                        }
                                    }
                                }
                                .clipShape(.capsule)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity,
                       alignment: .center)
                
                VStack {
#if DEBUG
                    HStack {
                        // String(describing:) used to prevent localisation
                        Button(String(describing: "Back (DEBUG)"), systemImage: "arrow.left", action: { viewModel.stepStage(by: -1) })
                            .clipShape(.capsule)
                        
                        Button(String(describing: "Exit (DEBUG)"), systemImage: "xmark", action: { isOnboardingPresented = false })
                            .clipShape(.capsule)

                        Button(String(describing: "Restart (DEBUG)"), systemImage: "arrow.trianglehead.clockwise", action: { viewModel.reset() })
                            .clipShape(.capsule)
                    }
#endif // DEBUG

                    Text("(this software is currently in its alpha stage.)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom)
            }
            .background(
                ColorfulView(
                    color: $colorfulViewColors
                )
            )
        }
        .foregroundStyle(.white)
        .navigationTitle("Mythic Setup")
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Getting Mythic set up"
                presence.state = "Onboarding"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"

                return presence
            }())
        }
    }
}

private extension OnboardingView {
    struct WelcomeStage: View {
        var body: some View {
            Text("Welcome to Mythic.")
                .font(.title)
                .bold()
        }
    }
    
    struct SignInStage: View {
        var body: some View {
            AccountsView()
        }
    }

    struct GreetingStage: View {
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Hi,")
                        .font(.largeTitle.bold())

                    Spacer()
                        .frame(width: 50)
                        .fixedSize()

                    VStack(alignment: .leading) {
                        if let user = try? Legendary.retrieveUser() {
                            HStack {
                                Label(user, systemImage: "chevron.right")
                                    .font(.title2.bold())

                                Image("EGFaceless")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 25)
                            }
                        }
                        /*
                        HStack {
                            Text("􀆊 placeholder steam (soon)")
                                .font(.title2.bold())
                            Image("Steam")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                        }
                         */
                    }
                }
            }
        }
    }

    struct RosettaStage: View {
        @Binding var isPresented: Bool

        @State private var installationError: Error?
        @State private var installationComplete: Bool = false

        var body: some View {
            RosettaInstallationView(
                isPresented: $isPresented,
                installationError: $installationError,
                installationComplete: $installationComplete
            )
        }
    }

    struct EngineStage: View {
        @Binding var isPresented: Bool

        @State private var installationError: Error?
        @State private var installationComplete: Bool = false
        var body: some View {
            EngineInstallationView(
                isPresented: $isPresented,
                installationError: $installationError,
                installationComplete: $installationComplete
            )
        }
    }

    struct DefaultContainerSetupStage: View {
        @Binding var isPresented: Bool

        @State private var bootError: Error?
        @State private var isBootErrorAlertPresented: Bool = false
        @State private var isDefaultContainerInitialised: Bool = false

        @MainActor
        func propagateBootSuccess() {
            withAnimation {
                isDefaultContainerInitialised = true
            }
        }

        var body: some View {
            VStack {
                if isDefaultContainerInitialised {
                    ContentUnavailableView(
                        "The default container is initialised.",
                        systemImage: "checkmark"
                    )
                    .task {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isPresented = false
                        }
                    }
                } else {
                    HStack {
                        Text("Setting up default container...")
                            .font(.largeTitle)
                            .bold()
                        
                        ProgressView()
                            .controlSize(.small)
                            .task {
                                do {
                                    _ = try await Wine.createContainer(name: "Default")
                                    propagateBootSuccess()
                                } catch is Wine.Container.AlreadyExistsError {
                                    propagateBootSuccess()
                                } catch {
                                    bootError = error
                                    isBootErrorAlertPresented = true
                                }
                            }
                    }
                }
            }
            .task(priority: .high) { @MainActor in
                // no mythic engine means no container setup ☹️☹️
                if !Engine.isInstalled {
                    isPresented = false
                }
                // if ~~default~~ ANY bottle already exists — no need to waste time/potentially break stuff calling wineboot
                if !Wine.containerURLs.isEmpty {
                    isDefaultContainerInitialised = true
                }
            }
            .alert(
                "Unable to initialise default container.",
                isPresented: $isBootErrorAlertPresented,
                presenting: bootError
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

    struct FinishedStage: View {
        var body: some View {
            Text("Ready to go!")
                .font(.title)
                .bold()

            Text("Mythic is now ready for use.")
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(NetworkMonitor.shared)
}
