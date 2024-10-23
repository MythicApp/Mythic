//
//  OnboardingR2.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/4/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import ColorfulX
import SwordRPC
import UserNotifications

struct OnboardingR2: View { // TODO: ViewModel
    
    init(fromPhase: Phase = .logo) {
        self.currentPhase = fromPhase
    }
    
    @ObservedObject private var mythicSettings = MythicSettings.shared
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    enum Phase: CaseIterable {
        case logo
        case welcome
        case signin,
             greetings
        case rosettaDisclaimer,
             rosettaInstaller
        case engineDisclaimer,
             engineDownloader,
             engineInstaller
        case defaultContainerSetup
        case finished
        
        mutating func next(forceNext: Bool = false) {
            let allCases = Self.allCases
            guard let currentIndex = allCases.firstIndex(of: self) else { return }
            var nextIndex = allCases.index(after: currentIndex)
            if nextIndex >= allCases.count {
                return
            }
            if !forceNext {
                if case .signin = allCases[nextIndex], Legendary.signedIn() {
                    nextIndex += 1
                }
                if case .greetings = allCases[nextIndex], !Legendary.signedIn() {
                    nextIndex += 1
                }
                if case .rosettaDisclaimer = allCases[nextIndex], (Rosetta.exists || !workspace.isARM()) {
                    // swiftlint:disable:previous control_statement
                    nextIndex += 2 // FIXME: dynamic approach using names (String(describing: <#Phase#>))
                }
                if case .engineDisclaimer = allCases[nextIndex], Engine.exists {
                    nextIndex += 3 // FIXME: dynamic approach using names (String(describing: <#Phase#>))
                }
            }
            self = allCases[nextIndex]
        }
        
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentPhase: Phase
    @State private var staticPhases: [Phase] = [.logo, .greetings, .rosettaInstaller, .engineDownloader, .engineInstaller, .defaultContainerSetup]
    
    @State private var colorfulAnimationColors: [Color] = [
        .init(hex: "#5412F6"),
        .init(hex: "#7E1ED8"),
        .init(hex: "#2C2C2C")
    ]
    @State private var colorfulAnimationSpeed: Double = 1
    @State private var colorfulAnimationNoise: Double = 0
    
    @State private var isOpacityAnimated: Bool = false
    @State private var areOthersAnimated: Bool = false
    
    @State private var isSecondRowPresented: Bool = false
    @State private var isThirdRowPresented: Bool = false
    @State private var isHelpPresented: Bool = false
    
    @State private var isSkipAlertPresented: Bool = false
    
    @State private var isNextButtonDisabled: Bool = false
    
    @State private var errorString: String?
    
    @State private var isHoveringOverDestructiveButton: Bool = false
    
    @State private var isSigningIn: Bool = false
    @State private var epicSigninAuthKey: String = .init()
    @State private var epicUnsuccessfulSignInAttempt: Bool = false
    
    @State private var agreedToRosettaSLA: Bool = false
    
    @State private var installationProgress: Double = 0.0
    @State private var isStopInstallAlertPresented: Bool = false
    @State private var engineInstallationComplete: Bool = false
    
    func nextAnimation() {
        withAnimation(.easeOut(duration: 2)) {
            isOpacityAnimated = true
        }
        
        withAnimation(.easeOut(duration: 1)) {
            areOthersAnimated = true
        } completion: {
                withAnimation(.easeOut(duration: 0.3)) {
                    isSecondRowPresented = true
                } completion: {
                    if !staticPhases.contains(currentPhase) { // || is garbage
                        withAnimation(.easeOut(duration: 0.3)) {
                            isThirdRowPresented = true
                        }
                    } else if [.logo, .greetings].contains(currentPhase) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            animateNextPhase()
                        }
                    }
                }
        }
    }
    
    var animationLock: NSLock = .init()
    func animateNextPhase(phase: Phase? = nil) {
        animationLock.lock()
        withAnimation(.easeInOut(duration: 1)) {
            isOpacityAnimated = false
            isSecondRowPresented = false
            isThirdRowPresented = false
            areOthersAnimated = false
            colorfulAnimationSpeed = 3.5
        } completion: {
            colorfulAnimationSpeed = 1
            if let phase = phase {
                currentPhase = phase
            } else {
                currentPhase.next()
            }
            nextAnimation()
            animationLock.unlock()
        }
    }
    
    func signIn(type: Game.Source) {
        switch type {
        case .epic:
            Task(priority: .userInitiated) {
                withAnimation { isSigningIn = true }
                do {
                    epicUnsuccessfulSignInAttempt = !(try await Legendary.signIn(authKey: epicSigninAuthKey))
                } catch {
                    errorString = error.localizedDescription
                }
                withAnimation { isSigningIn = false }
            }
        case .local:
            do {} // why
        }
    }
    
    var body: some View {
        ZStack {
            ColorfulView(color: $colorfulAnimationColors, speed: $colorfulAnimationSpeed, noise: $colorfulAnimationNoise)
                .ignoresSafeArea()
            
            VStack {
                VStack {
                    if errorString == nil {
                        switch currentPhase {
                        case .logo: // MARK: Phase: Logo
                            Image("MythicIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .shadow(radius: 30)
                        case .welcome: // MARK: Phase: Logo
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Welcome to Mythic."),
                                thirdRow: [
                                    .nextArrow(function: { animateNextPhase() })
                                ]
                            )
                        case .signin: // MARK: Phase: Logo
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Sign in to Epic Games"),
                                otherFirstRow: .init(
                                    Text("(optional)")
                                        .foregroundStyle(.placeholder)
                                        .font(.caption)
                                        .opacity(isSecondRowPresented ? 1.0 : 0.0)
                                ), secondRow: .init(
                                    VStack {
                                        HStack {
                                            Text("A link should've opened in your browser. If not, click")
                                            Link("here.", destination: URL(string: "https://legendary.gl/epiclogin")!)
                                                .foregroundStyle(.link)
                                            // .offset(x: -3, y: 0.5)
                                        }
                                        
                                        Text("Enter the 'authorisationCode' from the JSON response in the field below.")
                                        
                                        HStack {
                                            SecureField("Enter authorisation code...", text: $epicSigninAuthKey)
                                                .onSubmit { signIn(type: .epic) }
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                                .textFieldStyle(.roundedBorder)
                                            
                                            // .frame(width: 400, alignment: .center)
                                            
                                            if isSigningIn {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .padding(.leading, 5)
                                                    .ignoresSafeArea()
                                            } else if epicUnsuccessfulSignInAttempt {
                                                Image(systemName: "xmark")
                                                    .help("Mythic was unable to sign you in. Please try again.")
                                                    .padding(.leading, 5)
                                                    .ignoresSafeArea()
                                            }
                                        }
                                    }
                                        .onAppear {
#if !DEBUG
                                            workspace.open(URL(string: "http://legendary.gl/epiclogin")!)
#endif
                                        }
                                ), thirdRow: [
                                    .help(content: .init(
                                        Text("""
                                            Where it reads:
                                            "authorizationCode": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                                            Paste the 32 character long text into the text field.
                                            """)
                                        .padding()
                                    )),
                                    .nextArrow(function: {
                                        signIn(type: .epic)
                                    }, isButtonDisabled: epicSigninAuthKey.isEmpty || isSigningIn),
                                    .skipArrow(function: { isSkipAlertPresented = true }, isButtonDisabled: isSigningIn)
                                ]
                            )
                            .onAppear {
                                isNextButtonDisabled = true
                            }
                            .onChange(of: isSigningIn) {
                                if !$1, Legendary.signedIn() { // dumb logic, only checks signin status after pressing arrow
                                    animateNextPhase()
                                    notifications.add(
                                        .init(identifier: UUID().uuidString,
                                              content: {
                                                  let content = UNMutableNotificationContent()
                                                  content.title = "Signed in as \"\(Legendary.whoAmI())\"."
                                                  return content
                                              }(),
                                              trigger: nil)
                                    )
                                }
                            }
                        case .greetings: // MARK: Phase: Greetings
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                otherFirstRow: .init(
                                    HStack {
                                        Text("Hey, \(Legendary.whoAmI())!")
                                            .font(.bold(.title)())
                                            .scaledToFit()
                                            .truncationMode(.tail)
                                            .task { _ = try? Legendary.getInstallable() }
                                        
                                        Image("EGFaceless")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                )
                            )
                        case .rosettaDisclaimer: // MARK: Phase: Rosetta Disclaimer
                            // TODO: Skip if already installed (check for /Library/Apple/usr/share/rosetta/rosetta)
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Install Rosetta 2"),
                                secondRow: .init(
                                    VStack {
                                        Text(
                                            """
                                            Rosetta 2 enables a Mac with Apple silicon to use apps
                                            built for a Mac with an Intel processor.
                                            
                                            It's a key component for Windows® game functionality.
                                            
                                            To install Rosetta, you must confirm you have read and agreed
                                            to the terms of the software license agreement.
                                            """
                                        )
                                        .multilineTextAlignment(.center)
                                        
                                        HStack {
                                            Text("A list of Apple SLAs may be found")
                                            Link("here.", destination: URL(string: "https://www.apple.com/legal/sla/")!)
                                                .foregroundStyle(.link)
                                        }
                                        
                                        Toggle("I have read and agreed to the terms of the software license agreement.", isOn: $agreedToRosettaSLA)
                                    }
                                ), thirdRow: [
                                    .nextArrow(function: { animateNextPhase() }, isButtonDisabled: !agreedToRosettaSLA),
                                    .skipArrow(function: { isSkipAlertPresented = true })
                                ]
                            )
                        case .rosettaInstaller: // MARK: Phase: Rosetta Installer
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Installing Rosetta 2..."),
                                secondRow: .init(
                                    HStack {
                                        if installationProgress > 0.0 {
                                            ProgressView(value: installationProgress / 100)
                                                .progressViewStyle(.linear)
                                        } else {
                                            ProgressView()
                                                .progressViewStyle(.linear)
                                        }
                                        
                                        Text("\(Int(installationProgress))%")
                                            
                                        Button {
                                            isStopInstallAlertPresented = true
                                        } label: {
                                            Image(systemName: "xmark")
                                                .padding(5)
                                                .foregroundStyle(isHoveringOverDestructiveButton ? .red : .primary)
                                        }
                                        .clipShape(.circle)
                                        .help("Stop installing Rosetta 2")
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.1)) { isHoveringOverDestructiveButton = hovering }
                                        }
                                        .alert(isPresented: $isStopInstallAlertPresented) {
                                            Alert(
                                                title: .init("Are you sure you want to stop installing Rosetta 2?"),
                                                message: .init("This will limit your ability to play Windows® games."),
                                                primaryButton: .destructive(.init("Stop")) { 
                                                    // swiftlint:disable:next force_try
                                                    _ = try! Process.execute("/bin/bash", arguments: ["-c", "kill $(pgrep -fa 'softwareupdate --install-rosetta')"])
                                                    animateNextPhase()
                                                },
                                                secondaryButton: .cancel()
                                            )
                                        }
                                    }
                                        .task(priority: .userInitiated) {
                                            do {
                                                try await Rosetta.install(agreeToSLA: agreedToRosettaSLA) {
                                                    installationProgress = $0
                                                }
                                            } catch {
                                                errorString = error.localizedDescription
                                            }
                                        }
                                    
                                        .onChange(of: installationProgress) {
                                            if $1 == 100 { animateNextPhase() }
                                        }
                                    
                                        .onDisappear {
                                            installationProgress = 0.0
                                        }
                                )
                            )
                        case .engineDisclaimer: // MARK: Phase: Mythic Engine Disclaimer
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Install Mythic Engine"),
                                otherFirstRow: .init(
                                    Text("(optional)")
                                        .foregroundStyle(.placeholder)
                                        .font(.caption)
                                        .opacity(isSecondRowPresented ? 1.0 : 0.0)
                                ), secondRow: .init(
                                    Text(
                                        """
                                        In order to launch and run Windows® games, Mythic must download
                                        a specialized translation layer.
                                        
                                        The download time should take ~10 minutes,
                                        with an average internet connection.
                                        """
                                    )
                                    .multilineTextAlignment(.center)
                                ), thirdRow: [
                                    .nextArrow(function: { animateNextPhase() }),
                                    .skipArrow(function: { isSkipAlertPresented = true }),
                                    .help(content: .init(
                                        Text("""
                                        Mythic Engine is Mythic's implementation of Apple's game porting toolkit (GPTK),
                                        which combines wine and D3DMetal, to create a windows gaming experience on macOS.
                                        Similar to Proton, Mythic Engine attempts to be an emulator-like experience that
                                        enables native Windows games to be playable on macOS, while coming closer to native
                                        performance than ever before. (performance will vary between games)
                                        """)
                                    ))
                                ]
                            )
                        case .engineDownloader: // MARK: Phase: Mythic Engine Downloader
                            ContentView( // create downloader view for .rosettainstaller, .enginedownloader, and .engineinstaller
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Downloading Mythic Engine..."),
                                secondRow: .init(
                                    HStack {
                                        if installationProgress > 0.0 {
                                            ProgressView(value: installationProgress)
                                                .progressViewStyle(.linear)
                                        } else {
                                            ProgressView()
                                                .progressViewStyle(.linear)
                                        }
                                        
                                        Text("\(Int(installationProgress * 100))%")
                                            
                                        Button {
                                            isStopInstallAlertPresented = true
                                        } label: {
                                            Image(systemName: "xmark")
                                                .padding(5)
                                                .foregroundStyle(isHoveringOverDestructiveButton ? .red : .primary)
                                        }
                                        .clipShape(.circle)
                                        .help("Stop installing Mythic Engine (Not implemented)")
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.1)) { isHoveringOverDestructiveButton = hovering }
                                        }
                                        .alert(isPresented: $isStopInstallAlertPresented) {
                                            Alert(
                                                title: .init("Are you sure you want to stop installing Mythic Engine?"),
                                                message: .init("This will limit your ability to play Windows® games."),
                                                primaryButton: .destructive(.init("Stop")) {
                                                    animateNextPhase()
                                                },
                                                secondaryButton: .cancel()
                                            )
                                        }
                                        .disabled(true)
                                    }
                                )
                            )
                            .task(priority: .userInitiated) {
                                do {
                                    try await Engine.install(
                                        downloadHandler: { progress in
                                            installationProgress = progress.fractionCompleted
                                        }, installHandler: { completion in
                                            engineInstallationComplete = completion
                                        }
                                    )
                                } catch {
                                    errorString = error.localizedDescription
                                }
                            }
                            .onChange(of: installationProgress) {
                                if $1 == 1.0 { animateNextPhase() }
                            }
                            
                        case .engineInstaller: // MARK: Phase: Mythic Engine Installer (might get unified)
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Installing Mythic Engine..."),
                                secondRow: .init(
                                    ProgressView()
                                        .progressViewStyle(.linear)
                                )
                            )
                            .onChange(of: engineInstallationComplete) {
                                if $1 == true { animateNextPhase() }
                            }
                        case .defaultContainerSetup: // MARK: Phase: Default Container Setup
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("Setting up default container..."),
                                secondRow: .init(
                                    VStack {
                                        Text(
                                            """
                                            Mythic is setting up the default filesystem container for Windows®.
                                            This shouldn't take too long.
                                            """
                                        )
                                        ProgressView()
                                            .progressViewStyle(.linear)
                                    }
                                )
                            )
                            .task(priority: .userInitiated) {
                                await Wine.boot(name: "Default") { result in
                                    switch result {
                                    case .success:
                                        animateNextPhase()
                                    case .failure(let failure):
                                        guard type(of: failure) != Wine.ContainerAlreadyExistsError.self else { animateNextPhase(); return }
                                        errorString = failure.localizedDescription
                                    }
                                }
                            }
                            
                        case .finished: // MARK: Phase: Finished
                            ContentView(
                                isOpacityAnimated: $isOpacityAnimated,
                                isSecondRowPresented: $isSecondRowPresented,
                                isThirdRowPresented: $isThirdRowPresented,
                                label: Text("You're all set!"),
                                secondRow: .init(
                                    Text("Mythic is now ready to use.")
                                ), thirdRow: [
                                    .nextArrow(function: { mythicSettings.data.hasCompletedOnboarding = true })
                                ]
                            )
                        }
                    } else {
                        ContentView(
                            isOpacityAnimated: $isOpacityAnimated,
                            isSecondRowPresented: $isSecondRowPresented,
                            isThirdRowPresented: $isThirdRowPresented,
                            label: Text("Onboarding has failed to complete."),
                            secondRow: .init(
                                VStack {
                                    Text("\(errorString!)")
                                    Text("(Please restart Mythic.)")
                                        .font(.caption)
                                        .foregroundStyle(.placeholder)
                                }
                            ), thirdRow: []
                        )
                        .task {
                            colorfulAnimationColors = [
                                .init(hex: "#000000")
                            ]
                        }
                    }
                }
                .opacity(isOpacityAnimated ? 1.0 : 0.0)
                .offset(y: [.welcome, .greetings].contains(currentPhase) ? (areOthersAnimated ? 0 : 30) : 0)
                .blur(radius: areOthersAnimated ? 0 : 5)
                
                .onAppear { nextAnimation() }
                .alert(isPresented: $isSkipAlertPresented) {
                    Alert(
                        title: .init("Are you sure you want to skip this section?"),
                        primaryButton: .default(.init("Skip")) { // FIXME: dirtyfix
                            if case .signin = currentPhase {
                                animateNextPhase(phase: .rosettaDisclaimer)
                            } else if case .rosettaDisclaimer = currentPhase {
                                animateNextPhase(phase: .engineDisclaimer)
                            } else if case .engineDisclaimer = currentPhase {
                                animateNextPhase(phase: .finished)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .foregroundStyle(.white)
            .frame(width: 450)
            
            VStack {
                Spacer()
                Text("(alpha)")
                    .font(.footnote)
                    .foregroundStyle(.placeholder)
                    .padding(.bottom)
            }
        }
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

extension OnboardingR2 {
    struct ContentView: View {
        @Binding var isOpacityAnimated: Bool
        @Binding var isSecondRowPresented: Bool
        @Binding var isThirdRowPresented: Bool
        
        @State private var isHelpPopoverPresented: Bool = false
        
        // swiftlint:disable:next nesting
        enum ThirdRow { // TODO: ViewBuilder?
            case help(content: AnyView?)
            case nextArrow(
                function: (() -> Void)?,
                isButtonDisabled: Bool? = nil
            )
            case skipArrow(
                function: (() -> Void)?,
                isButtonDisabled: Bool? = nil
            )
            case custom(content: AnyView?)
        }
        
        var label: Text?
        var otherFirstRow: AnyView?
        var secondRow: AnyView?
        var thirdRow: [ThirdRow]?
        
        var body: some View {
            VStack {
                label
                    .font(.bold(.title)())
                
                otherFirstRow
                
                if secondRow != nil {
                    Spacer()
                        .frame(height: 10)
                }
                
                if isOpacityAnimated {
                    secondRow
                        .opacity(isSecondRowPresented ? 1.0 : 0.0)
                }
                
                if let thirdRow = thirdRow, isSecondRowPresented {
                    HStack {
                        ForEach(thirdRow.indices, id: \.self) { index in
                            switch thirdRow[index] {
                            case .help(let content):
                                Button { isHelpPopoverPresented = true } label: {
                                    Image(systemName: "questionmark.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                }
                                .help("Help")
                                .buttonStyle(.plain)
                                .popover(isPresented: $isHelpPopoverPresented, content: { content })
                            case .nextArrow(let function, let isDisabled):
                                Button {
                                    function?()
                                } label: {
                                    Image(systemName: "arrow.right")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                }
                                .help("Next")
                                .buttonStyle(.plain)
                                .disabled(isDisabled ?? false)
                            case .skipArrow(let function, let isDisabled):
                                Button {
                                    function?()
                                } label: {
                                    Image(systemName: "arrow.right.to.line")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                }
                                .help("Skip")
                                .buttonStyle(.plain)
                                .disabled(isDisabled ?? false)
                            case .custom(let content):
                                content
                            }
                        }
                    }
                    .opacity(isThirdRowPresented ? 1 : 0)
                    .blur(radius: isThirdRowPresented ? 0 : 5)
                }
            }
        }
    }
    
    struct InstallerView: View {
        var body: some View {
            /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Hello, world!@*/Text("Hello, world!")/*@END_MENU_TOKEN@*/ // TODO: TODO
        }
    }
}

#Preview {
    OnboardingR2(fromPhase: .logo)
        .environmentObject(NetworkMonitor())
}
