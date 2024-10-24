//
//  OnboardingView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/23/24.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("isOnboardingPresented") private var isOnboardingPresented: Bool = true
    @State private var currentStep: Steps = .intro
    @State private var completedSteps: Set<Steps> = []
    @State private var skippedSteps: Set<Steps> = []
    @State private var canGoNext: Bool = false
    @State private var canGoSkip: Bool = false
    
    private enum Steps: Int, Identifiable {
        var id: Int { self.rawValue }
        case intro
        case epicGamesSignIn
        case epicGamesSigningIn
        case rosettaTerms
        case rosettaInstallation
        case engineConfig
        case engineInstallation
        case engineContainer
        case outro

        static let stepsOrder: [Steps] = [
            .intro,
            .epicGamesSignIn,
            .epicGamesSigningIn,
            .rosettaTerms,
            .rosettaInstallation,
            .engineConfig,
            .engineInstallation,
            .engineContainer,
            .outro
        ]
        
        var textContent: LocalizedStringResource {
            switch self.equivalentStep {
            case .intro: "Welcome"
            case .epicGamesSignIn: "Epic Games Setup"
            case .rosettaTerms: "Rosetta Setup"
            case .engineConfig: "Engine Setup"
            case .outro: "Finish"
            default: "Unknown"
            }
        }
        
        var equivalentStep: Steps {
            switch self {
            case .intro: .intro
            case .epicGamesSignIn: .epicGamesSignIn
            case .epicGamesSigningIn: .epicGamesSignIn
            case .rosettaTerms: .rosettaTerms
            case .rosettaInstallation: .rosettaTerms
            case .engineConfig: .engineConfig
            case .engineInstallation: .engineConfig
            case .engineContainer: .engineConfig
            case .outro: .outro
            }
        }
        
        var nextStep: Steps? {
            guard let index = Self.stepsOrder.firstIndex(of: self) else { return nil }
            return index + 1 < Self.stepsOrder.count ? Self.stepsOrder[index + 1] : nil
        }

        var skipStep: Steps? {
            var step = self.nextStep
            while let stepData = step, stepData.equivalentStep != stepData {
                step = stepData.nextStep
            }

            return step
        }
    }
    
    private let stepsDisplayOrder: [Steps] = [.intro, .epicGamesSignIn, .rosettaTerms, .engineConfig, .outro]
    private let skipMap: [Steps: [Steps]] = [
        .rosettaTerms: [.engineConfig]
    ]
    
    private struct StepView: View {
        var step: Steps
        @Binding var currentStep: Steps
        @Binding var completedSteps: Set<Steps>
        @Binding var skippedSteps: Set<Steps>
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName:
                        currentStep.equivalentStep == step ? "circle.fill"
                      : completedSteps.contains(step) ? "checkmark.circle"
                      : skippedSteps.contains(step) ? "minus"
                      : "circle.dashed")
                .resizable()
                .contentTransition(.interpolate)
                .scaledToFit()
                .frame(width: 8, height: 8)
                Text(step.textContent)
            }
            .opacity(currentStep.equivalentStep == step ? 1 : 0.6)
            .scaleEffect(currentStep.equivalentStep == step ? 1 : 0.8, anchor: .leading)
        }
    }
    
    private static var moveAndFadeNext: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .offset(x: 32).combined(with: .opacity),
            removal: .offset(x: -32).combined(with: .opacity)
        )
    }
    
    private struct IntroStepView: View {
        @Binding var canGoNext: Bool
        @Binding var canGoSkip: Bool

        @State private var animateIcon: Bool = false
        @State private var animateText: Bool = false

        var body: some View {
            VStack(spacing: 8) {
                if animateIcon {
                    Image("MythicIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .shadow(radius: 30)
                        .transition(.offset(y: -32).combined(with: .opacity))
                        .padding()
                }
                if animateText {
                    Text("Welcome to Mythic!")
                        .font(.title)
                        .bold()
                        .transition(.offset(y: 32).combined(with: .opacity))
                }
            }
            .onAppear {
                withAnimation {
                    canGoNext = false
                    canGoSkip = false
                }
                withAnimation(.spring(duration: 1)) {
                    animateIcon = true
                }
                withAnimation(.spring(duration: 1).delay(1.25)) {
                    animateText = true
                    canGoNext = true
                }
            }
        }
    }
    
    private struct EpicGamesLoginStepView: View {
        @Binding var canGoNext: Bool
        @Binding var canGoSkip: Bool
        @Binding var currentStep: Steps
        var goNext: () -> Void
        
        @State private var authorizationCode: String = ""
        @State private var signInState: SignInState = .none
        @State private var errorShown = false
        
        @Environment(\.openURL) var openURL
        
        private enum SignInState: Equatable {
            case none
            case loading
            case success
            case loginFailure
            case failure(String)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to Epic Games")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Enter the authorization code into the text field below.")
                        .tint(.secondary)
                }
                HStack(spacing: 8) {
                    SecureField("Authorization Code", text: $authorizationCode)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: authorizationCode) {
                            withAnimation {
                                canGoNext = !authorizationCode.isEmpty
                            }
                        }
                        .disabled(signInState != .none)
                    Button("Get Code") {
                        if let url = URL(string: "https://legendary.gl/epiclogin") {
                            openURL(url)
                        }
                    }
                    .disabled(signInState != .none)
                    if signInState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                }
            }
            .alert("Epic Games Login Error", isPresented: $errorShown, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                switch signInState {
                case .failure(let string):
                    Text("Legendary error: \(string)")
                default:
                    Text("The Epic Games authorization code was invalid.")
                }
            })
            .multilineTextAlignment(.leading)
            .onAppear {
                withAnimation {
                    canGoNext = false
                    canGoSkip = true
                }
            }
            .onChange(of: errorShown) {
                if !errorShown {
                    withAnimation {
                        canGoNext = !authorizationCode.isEmpty
                        canGoSkip = true
                        signInState = .none
                        currentStep = .epicGamesSignIn
                    }
                }
            }
            .onChange(of: currentStep) {
                if currentStep == .epicGamesSigningIn {
                    Task(priority: .userInitiated) {
                        withAnimation {
                            signInState = .loading
                            canGoNext = false
                            canGoSkip = false
                        }
                        
                        var signInSuccess: Bool = false
                        var errorString: String?
                        do {
                            signInSuccess = try await Legendary.signIn(authKey: authorizationCode)
                        } catch {
                            errorString = error.localizedDescription
                        }
                        
                        withAnimation {
                            if signInSuccess {
                                signInState = .success
                                goNext()
                            } else if let error = errorString {
                                signInState = .failure(error)
                                errorShown = true
                            } else {
                                signInState = .loginFailure
                                errorShown = true
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private struct RosettaInstallationStepView: View {
        @Binding var canGoNext: Bool
        @Binding var canGoSkip: Bool
        @Binding var currentStep: Steps

        @State private var installationLogs: [String] = []
        @State private var didFail: Bool = false
        @State private var didComplete: Bool = false
        @State private var isInstalling: Bool = false

        private var filteredLogs: [String] {
            installationLogs.filter { !$0.isEmpty }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rosetta 2 Installation")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Installing Rosetta 2...")
                        .tint(.secondary)
                }
                VStack(spacing: 2) {
                    if isInstalling {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(filteredLogs.indices, id: \.self) { index in
                                    Text(filteredLogs[index])
                                        .font(.system(.body, design: .monospaced))
                                }
                                VStack {}
                                    .frame(maxWidth: .infinity, maxHeight: 0)
                                    .id("term-bottom")
                            }
                            .onChange(of: installationLogs) {
                                withAnimation {
                                    proxy.scrollTo("term-bottom")
                                }
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.textBackgroundColor))
                    .overlay {
                        if didComplete {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64)
                                    .transition(.scale(scale: 1.2))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .transition(.scale(scale: 1.2).combined(with: .opacity))
                        } else {
                            EmptyView()
                        }
                    }
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            .alert("Rosetta Installation Error", isPresented: $didFail, actions: {
                    Button("OK", role: .cancel) {}
                }, message: {
                    Text("Rosetta failed to install. Skip or try again later.")
                })
            .onAppear {
                withAnimation {
                    canGoNext = false
                    canGoSkip = false
                }
                
                installRosetta()
            }
            .onChange(of: didFail) {
                if !didFail {
                    currentStep = .rosettaTerms
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        
        func installRosetta() {
            let logger = AppLogger(category: Self.self)

            installationLogs = []
            withAnimation {
                didFail = false
                didComplete = false
                isInstalling = true
            }
        
            Task(priority: .userInitiated) {
                var fail = false
                do {
                    logger.debug("Starting Rosetta installation...")
                    try await Rosetta.install(agreeToSLA: true) { line in
                        installationLogs.append(line)
                        logger.debug("Rosetta installation log: \(line)")
                    }
                    logger.debug("Finished Rosetta installation...")
                } catch {
                    fail = true
                }
                
                withAnimation {
                    isInstalling = false
                    if fail {
                        didFail = true
                    } else {
                        didComplete = true
                        canGoNext = true
                    }
                }
            }
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mythic Setup Assistant")
                    .font(.title)
                    .bold()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stepsDisplayOrder) { step in
                        StepView(step: step, currentStep: $currentStep, completedSteps: $completedSteps, skippedSteps: $skippedSteps)
                    }
                }
            }
            .padding(32)
            .frame(width: 320, height: nil, alignment: .leading)
            .frame(maxHeight: .infinity)
            .multilineTextAlignment(.leading)
            .background(ColorfulBackgroundView())
            VStack {
                VStack(spacing: 16) {
                    switch currentStep {
                    case .intro:
                        IntroStepView(canGoNext: $canGoNext, canGoSkip: $canGoSkip)
                            .transition(Self.moveAndFadeNext)
                    case .epicGamesSignIn, .epicGamesSigningIn:
                        EpicGamesLoginStepView(canGoNext: $canGoNext, canGoSkip: $canGoSkip, currentStep: $currentStep, goNext: {
                            goNext()
                        })
                            .transition(Self.moveAndFadeNext)
                    case .rosettaTerms:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rosetta 2 Installation")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Rosetta 2 is required for Windows game compatibility. By installing Rosetta 2, you agree to the terms and conditions of the software found at [https://www.apple.com/legal/sla/](https://www.apple.com/legal/sla/).")
                                .tint(.secondary)
                                .multilineTextAlignment(.leading)
                            VStack {
                                Image(systemName: "square.and.arrow.down")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 96)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .onAppear {
                            withAnimation {
                                canGoNext = true
                                canGoSkip = true
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(Self.moveAndFadeNext)
                    case .rosettaInstallation:
                        RosettaInstallationStepView(canGoNext: $canGoNext, canGoSkip: $canGoSkip, currentStep: $currentStep)
                            .transition(Self.moveAndFadeNext)
                    case .engineInstallation:
                        EmptyView()
                    case .engineConfig:
                        EmptyView()
                    case .engineContainer:
                        EmptyView()
                    case .outro:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Spacer()
                    if getSkipStep() != nil, canGoSkip {
                        Button {
                            withAnimation(.spring(duration: 0.5)) {
                                goSkip()
                            }
                        } label: {
                            Text("Skip")
                                .padding(4)
                        }
                    }
                    if getNextStep() != nil {
                        Button {
                            withAnimation(.spring(duration: 0.5)) {
                                goNext()
                            }
                        } label: {
                            Text("Next")
                                .padding(4)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                        .disabled(!canGoNext)
                    } else if canGoNext {
                        Button {
                            isOnboardingPresented = false
                        } label: {
                            Text("Finish")
                                .padding(4)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .padding(.top)
        }
        .onAppear {
            if Rosetta.exists {
//                completedSteps.insert(.rosettaTerms)
            }
        }
        .frame(minWidth: 768, minHeight: 512)
    }

    private func getNextStep() -> Steps? {
        var nextStep = currentStep.nextStep
        while let step = nextStep, skippedSteps.contains(step) || completedSteps.contains(step) {
            nextStep = step.nextStep
        }

        return nextStep
    }

    private func getSkipStep() -> Steps? {
        var skipStep = currentStep.skipStep
        while let step = skipStep, skippedSteps.contains(step) || completedSteps.contains(step) {
            skipStep = step.skipStep
        }

        return skipStep
    }
    
    private func goNext() {
        completedSteps.insert(currentStep)
        guard let nextStep = getNextStep() else { return }
        currentStep = nextStep
    }

    private func goSkip() {
        skippedSteps.insert(currentStep)
        if let additionalSkips = skipMap[currentStep.equivalentStep] {
            skippedSteps.formUnion(additionalSkips)
        }

        guard let skipStep = getSkipStep() else { return }
        currentStep = skipStep
    }
}

#Preview {
    OnboardingView()
        .frame(width: 768, height: 512)
}
