//
//  OnboardingEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/2/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import MetalKit
import ColorfulX
import UserNotifications
import SwordRPC

struct OnboardingEvo: View {
    init(fromChapter: Chapter = .logo) {
        self.currentChapter = fromChapter
    }
    
    enum Chapter: CaseIterable {
        case logo
        case welcome
        case signIn, // only epic as of now
             greetings
        case engineDisclaimer,
             engineDownloader,
             engineInstaller,
             engineError
        case defaultBottleSetup,
             defaultBottleSetupError
        case finished
        
        @available(*, message: "Use of next() is discouraged.")
        mutating func next() {
            let allCases = Self.allCases
            guard let currentIndex = allCases.firstIndex(of: self) else { return }
            let nextIndex = allCases.index(after: currentIndex) % allCases.count
            self = allCases[nextIndex]
        }
    }
    
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true
    @State private var isOnboardingPresented: Bool = false
    
    @State private var currentChapter: Chapter
    
    @State private var animationColors: [Color] = [
        .init(hex: "#5412F6"),
        .init(hex: "#7E1ED8"),
        .init(NSColor.windowBackgroundColor)
    ]
    @State private var animationSpeed: Double = 1
    @State private var animationNoise: Double = 15
    
    @State private var isLogoOpacityAnimated: Bool = true
    @State private var isWelcomeOpacityAnimated: Bool = false
    @State private var isWelcomeOffsetAnimated: Bool = false
    
    @State private var isSignInOpacityAnimated: Bool = false
    @State private var isSignInOffsetAnimated: Bool = false
    @State private var epicAuthKey: String = .init()
    @State private var epicSigningIn: Bool = false
    @State private var epicSigninSuccess: Bool = false
    
    @State private var isGreetingsOpacityAnimated: Bool = false
    @State private var isGreetingsOffsetAnimated: Bool = false
    
    @State private var isEngineDisclaimerOpacityAnimated: Bool = false
    @State private var isEngineDisclaimerOffsetAnimated: Bool = false
    
    @State private var isInstallOpacityAnimated: Bool = false
    @State private var isInstallOffsetAnimated: Bool = false
    
    @State private var isDownloadOpacityAnimated: Bool = false
    @State private var isDownloadOffsetAnimated: Bool = false
    
    @State private var isEngineErrorOpacityAnimated: Bool = false
    @State private var isEngineErrorOffsetAnimated: Bool = false
    
    @State private var isSkipEngineInstallationAlertPresented: Bool = false
    
    @State private var isDefaultBottleSetupOpacityAnimated: Bool = false
    @State private var isDefaultBottleSetupOffsetAnimated: Bool = false
    
    @State private var isDefaultBottleSetupErrorOpacityAnimated: Bool = false
    @State private var isDefaultBottleSetupErrorOffsetAnimated: Bool = false
    
    @State private var isFinishedOpacityAnimated: Bool = false
    @State private var isFinishedOffsetAnimated: Bool = false
    
    @State private var isHelpPopoverPresented: Bool = false
    
    @State private var librariesDownloadProgress: Double = .init()
    @State private var librariesInstallProgress: Double = .init()
    @State private var librariesError: Error?
    
    @State private var bottleSetupError: Error?
    
    @State private var isSecondRowPresented: Bool = false
    
    private func epicSignIn() {
        Task(priority: .userInitiated) {
            epicSigningIn = true
            let success = await Legendary.signIn(authKey: epicAuthKey)
            epicSigninSuccess = success
            epicSigningIn = false
        }
    }
    
    var body: some View {
        ZStack {
            ColorfulView(
                color: $animationColors,
                speed: $animationSpeed,
                noise: $animationNoise
            )
            .ignoresSafeArea()
            
            VStack {
                switch currentChapter {
                // MARK: - Logo
                case .logo:
                    Image("MythicIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .opacity(isLogoOpacityAnimated ? 1.0 : 0.0)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isLogoOpacityAnimated = false
                                } completion: {
                                    currentChapter.next()
                                }
                                
                            }
                        }
                // MARK: - Logo
                case .welcome:
                    VStack {
                        Text("Welcome to Mythic.")
                            .font(.bold(.largeTitle)())
                            .opacity(isWelcomeOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isWelcomeOffsetAnimated ? 0 : 30)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2)) {
                                    isWelcomeOpacityAnimated = true
                                }
                                
                                withAnimation(.easeOut(duration: 1)) {
                                    isWelcomeOffsetAnimated = true
                                } completion: {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        isSecondRowPresented = true
                                    }
                                }
                            }
                        
                        Button(
                            action: {
                                withAnimation {
                                    isSecondRowPresented = false
                                    isWelcomeOpacityAnimated = false
                                } completion: {
                                    if !Legendary.signedIn() {
                                        currentChapter = .signIn
                                    } else if Legendary.signedIn() {
                                        currentChapter = .greetings
                                    } else if !Libraries.isInstalled() {
                                        currentChapter = .engineDisclaimer
                                    } else if Wine.allBottles?["Default"] == nil {
                                        currentChapter = .defaultBottleSetup
                                    } else {
                                        currentChapter = .finished
                                    }
                                }
                            }, label: {
                                Image(systemName: "arrow.right")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                            }
                        )
                        .buttonStyle(.borderless)
                        .opacity(isSecondRowPresented ? 1 : 0)
                    }
                    .foregroundStyle(.white)
                // MARK: - Sign In
                case .signIn:
                    VStack {
                        VStack {
                            Text("Sign in to Epic Games")
                                .font(.bold(.title)())
                                .foregroundStyle(.white)
                            Text("(optional)")
                                .foregroundStyle(.placeholder)
                                .font(.footnote)
                        }
                        .opacity(isSignInOpacityAnimated ? 1.0 : 0.0)
                        .offset(y: isSignInOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        VStack {
                            HStack {
                                Text("A link should've opened in your browser. If not, click")
                                    .foregroundStyle(.white)
                                Link("here.", destination: URL(string: "https://legendary.gl/epiclogin")!)
                            }
                            
                            Text("Enter the 'authorisationCode' from the JSON response in the field below.")
                                .foregroundStyle(.white)
                            
                            HStack {
                                TextField("Enter authorisation key...", text: $epicAuthKey)
                                    .onSubmit { epicSignIn() }
                                    .frame(width: 350, alignment: .center)
                                
                                Button(
                                    action: { epicSignIn() },
                                    label: {
                                        if epicSigningIn {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.right")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                        }
                                    }
                                )
                                .buttonStyle(.borderless)
                                .foregroundStyle(.white)
                            }
                        }
                        .opacity(isSecondRowPresented ? 1 : 0)
                        
                        HStack {
                            Button(action: {
                                isHelpPopoverPresented.toggle()
                            }, label: {
                                Image(systemName: "questionmark.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                            })
                            .buttonStyle(.borderless)
                            .popover(isPresented: $isHelpPopoverPresented, arrowEdge: .bottom) {
                                VStack {
                                    NotImplementedView()
                                }
                                .padding()
                            }
                            
                            Button(
                                action: {
                                    currentChapter = .greetings
                                }, label: {
                                    Image(systemName: "arrow.right.to.line")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                }
                            )
                            .disabled(epicSigningIn)
                            .help("Skip this step")
                            .buttonStyle(.borderless)
                        }
                        .foregroundStyle(.white)
                        .opacity(isSecondRowPresented ? 1 : 0)
                    }
                    .onChange(of: epicSigninSuccess) { _, newValue in
                        if newValue { currentChapter.next() }
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isSignInOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isSignInOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            } completion: {
                                workspace.open(URL(string: "http://legendary.gl/epiclogin")!)
                            }
                        }
                    }
                // MARK: - Greetings
                case .greetings:
                    VStack {
                        HStack {
                            Text("Hey, \(Legendary.whoAmI())!")
                                .font(.bold(.title)())
                                .scaledToFit()
                                .foregroundStyle(.white)
                                .task { _ = try? Legendary.getInstallable() }
                            
                            Image("EGFaceless")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                    }
                    .opacity(isGreetingsOpacityAnimated ? 1.0 : 0.0)
                    .offset(y: isGreetingsOffsetAnimated ? 0 : 30)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isGreetingsOpacityAnimated = true
                        } completion: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeInOut(duration: 1)) {
                                    isGreetingsOpacityAnimated = false
                                } completion: {
                                    if !Libraries.isInstalled() {
                                        currentChapter = .engineDisclaimer
                                    } else if Wine.allBottles?["Default"] == nil {
                                        currentChapter = .defaultBottleSetup
                                    } else {
                                        currentChapter = .finished
                                    }
                                }
                            }
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isGreetingsOffsetAnimated = true
                        }
                    }
                // MARK: - Engine Disclaimer
                case .engineDisclaimer:
                    VStack {
                        Text("Install Mythic Engine")
                            .font(.bold(.title)())
                        
                        Spacer()
                            .frame(height: 10)
                        
                        Text(
                            """
                            In order to launch Windows® games, Mythic must download
                            a specialized translation layer.
                            
                            The download time should take ~10 minutes or less,
                            depending on your internet connection.
                            """
                        )
                        .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isEngineDisclaimerOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isEngineDisclaimerOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
                    .opacity(isEngineDisclaimerOpacityAnimated ? 1.0 : 0.0)
                    .offset(y: isEngineDisclaimerOffsetAnimated ? 0 : 30)
                    
                    HStack {
                        Button(
                            action: {
                            isHelpPopoverPresented.toggle()
                        }, label: {
                            Image(systemName: "questionmark.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                        })
                        .buttonStyle(.borderless)
                        .popover(isPresented: $isHelpPopoverPresented, arrowEdge: .bottom) {
                            VStack {
                                Text(
                                """
                                Mythic Engine is Mythic's implementation of Apple's game porting toolkit (GPTK),
                                which combines wine and D3DMetal, to create a windows gaming experience on macOS.
                                Similar to Proton, Mythic Engine attempts to be an emulator-like experience that
                                enables native Windows games to be playable on macOS, while coming closer to native
                                performance than ever before. (performance will vary between games)
                                """
                                )
                                
                                HStack {
                                    Text("Check out Mythic Engine")
                                    Link("here.", destination: .init(string: "https://github.com/MythicApp/Engine-Evo")!)
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                        }
                        
                        Spacer()
                            .frame(width: 10)
                        
                        Button(
                            action: {
                                withAnimation {
                                    isSecondRowPresented = false
                                    isEngineDisclaimerOpacityAnimated = false
                                } completion: {
                                    currentChapter.next()
                                }
                                Task(priority: .userInitiated) {
                                    Libraries.install(
                                        downloadProgressHandler: { progress in
                                            librariesDownloadProgress = progress
                                            
                                            if progress == 1 {
                                                currentChapter = .engineInstaller
                                            }
                                        },
                                        
                                        installProgressHandler: { librariesInstallProgress = $0 },
                                        
                                        completion: { completion in
                                            switch completion {
                                            case .success:
                                                currentChapter = .defaultBottleSetup
                                            case .failure(let failure):
                                                    librariesError = failure
                                                    currentChapter = .engineError
                                            }
                                            
                                        }
                                    )
                                }
                            }, label: {
                                Image(systemName: "arrow.right")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                            }
                        )
                        .buttonStyle(.borderless)
                        
                        Button {
                            isSkipEngineInstallationAlertPresented = true
                        } label: {
                            Image(systemName: "arrow.right.to.line")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Skip this step")
                        .alert(isPresented: $isSkipEngineInstallationAlertPresented) {
                            Alert(
                                title: .init("Are you sure you want to skip Mythic Engine installation?"),
                                message: .init("Without Mythic Engine, you'll be unable to launch Windows® games."),
                                primaryButton: .default(.init("Skip")) { currentChapter = .finished },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    .foregroundStyle(.white)
                    .opacity(isSecondRowPresented ? 1 : 0)
                // MARK: - Engine Downloader
                case .engineDownloader:
                    VStack {
                        Text("Downloading Mythic Engine...")
                            .font(.bold(.title)())
                            .opacity(isDownloadOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isDownloadOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        HStack {
                            Text("\(Int(librariesDownloadProgress * 100))%")
                            
                            if librariesDownloadProgress != .init() {
                                ProgressView(value: librariesDownloadProgress)
                                    .progressViewStyle(.linear)
                                    .frame(width: 150)
                            } else {
                                ProgressView()
                                    .progressViewStyle(.linear)
                                    .frame(width: 150)
                            }
                        }
                        .opacity(isSecondRowPresented ? 1.0 : 0.0)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isDownloadOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isDownloadOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
                // MARK: - Engine Installer
                case .engineInstaller:
                    VStack {
                        Text("Installing Mythic Engine...")
                            .font(.bold(.title)())
                            .opacity(isInstallOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isInstallOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        HStack {
                            Text("\(Int(librariesInstallProgress * 100))%")
                            
                            if librariesInstallProgress != .init() {
                                ProgressView(value: librariesInstallProgress)
                                    .progressViewStyle(.linear)
                                    .frame(width: 150)
                            } else {
                                ProgressView()
                                    .progressViewStyle(.linear)
                                    .frame(width: 150)
                            }
                            
                        }
                        .opacity(isSecondRowPresented ? 1.0 : 0.0)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isInstallOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isInstallOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
                // MARK: - Engine Error
                case .engineError:
                    VStack {
                        Text("Failed to install Mythic Engine.")
                            .font(.bold(.title)())
                            .opacity(isEngineErrorOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isEngineErrorOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        Text(librariesError?.localizedDescription ?? "Unknown Error.")
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                        Text("(please restart Mythic.)")
                            .foregroundStyle(.placeholder)
                            .font(.footnote)
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isEngineErrorOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isEngineErrorOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
                // MARK: - Default Bottle Setup
                case .defaultBottleSetup:
                    VStack {
                        Text("Default Bottle Setup")
                            .font(.bold(.title)())
                            .opacity(isDefaultBottleSetupOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isDefaultBottleSetupOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        Text("Mythic is now setting up your default bottle to play Windows® games.")
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                        
                        ProgressView()
                            .controlSize(.small)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isDefaultBottleSetupOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isDefaultBottleSetupOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                        
                        Task(priority: .userInitiated) {
                            if Libraries.isInstalled() {
                                await Wine.boot(name: "Default") { result in
                                    switch result {
                                    case .success:
                                        currentChapter = .finished
                                    case .failure(let failure):
                                        guard type(of: failure) != Wine.BottleAlreadyExistsError.self else { currentChapter = .finished; return }
                                        bottleSetupError = failure
                                        currentChapter = .defaultBottleSetupError
                                    }
                                }
                            }
                        }
                    }
                    // MARK: - Default Bottle Setup Error
                case .defaultBottleSetupError:
                    VStack {
                        Text("Failed to set up default bottle.")
                            .font(.bold(.title)())
                            .opacity(isDefaultBottleSetupErrorOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isDefaultBottleSetupErrorOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        Text(bottleSetupError?.localizedDescription ?? "Unknown Error.")
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                        Text("(please restart Mythic.)")
                            .foregroundStyle(.placeholder)
                            .font(.footnote)
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        animationColors = [
                            .init(hex: "#5412F6"),
                            .init(hex: "#7E1ED8"),
                            .init(hex: "#2C2C2C"),
                            .init(hex: "#2C2C2C"),
                            .init(hex: "#2C2C2C"),
                            .init(hex: "#2C2C2C")
                        ]
                        
                        withAnimation(.easeInOut(duration: 2)) {
                            isDefaultBottleSetupErrorOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isDefaultBottleSetupErrorOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
                // MARK: - Finished
                case .finished:
                    VStack {
                        Text("You're all set!")
                            .font(.bold(.title)())
                            .opacity(isFinishedOpacityAnimated ? 1.0 : 0.0)
                            .offset(y: isFinishedOffsetAnimated ? 0 : 30)
                        
                        Spacer()
                            .frame(height: 10)
                        
                        Text("Mythic setup is now complete.")
                            .opacity(isSecondRowPresented ? 1.0 : 0.0)
                        
                        Button(
                            action: {
                                withAnimation {
                                    isSecondRowPresented = false
                                    isFinishedOpacityAnimated = false
                                } completion: {
                                    withAnimation {
                                        isFirstLaunch = false
                                    }
                                }
                                
                            }, label: {
                                Image(systemName: "arrow.right")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                            }
                        )
                        .buttonStyle(.borderless)
                        .opacity(isSecondRowPresented ? 1 : 0)
                        
                    }
                    .foregroundStyle(.white)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2)) {
                            isFinishedOpacityAnimated = true
                        }
                        
                        withAnimation(.easeOut(duration: 1)) {
                            isFinishedOffsetAnimated = true
                        } completion: {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isSecondRowPresented = true
                            }
                        }
                    }
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
}

#Preview {
    OnboardingEvo(fromChapter: .logo)
}
