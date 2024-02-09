//
//  Install.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Combine

extension OnboardingView {
    // MARK: - InstallView Struct
    /// A view guiding the user through the installation of the Game Porting Toolkit.
    struct InstallView: View { // TODO: revamp
        
        // MARK: - Binding Variables
        @Binding var isPresented: Bool
        
        // MARK: - Enumerations
        // swiftlint:disable:next nesting
        enum ActiveAlert {
            case closeConfirmation,
                 installError
        }
        
        // MARK: - State Variables
        @State private var isDownloadSheetPresented: Bool = false
        @State private var isInstallSheetPresented: Bool = false
        @State private var activeAlert: ActiveAlert = .closeConfirmation
        @State private var isAlertPresented: Bool = false
        @State private var downloadProgress: Double = 0
        @State private var installProgress: Double = 0
        @State private var installComplete: Bool = false
        @State private var installError: Bool = false
        @State private var isHelpPopoverPresented: Bool = false
        
        // MARK: - Body
        var body: some View {
            VStack {
                Text("Install Game Porting Toolkit")
                    .font(.title)
                
                Divider()
                
                Text(
                """
                In order to launch Windows® games, Mythic must download
                a special translator by Apple to convert Windows® code to macOS.
                 
                It's around 1.8GB in size, but the download is around 600MB due to compression.
                """
                )
                .multilineTextAlignment(.center)
                
                HStack {
                    // MARK: Close Button
                    Button("Close") {
                        if /* alreadyShownCloseConfirmation == false || */ Libraries.isInstalled() == false {
                            // alreadyShownCloseConfirmation = true
                            activeAlert = .closeConfirmation
                            isAlertPresented = true
                        } else {
                            isPresented = false
                        }
                    }
                    
                    // MARK: Install Button
                    Button(Libraries.isInstalled() ? "Installed" : "Install") {
                        Libraries.install(
                            downloadProgressHandler: { progress in
                                downloadProgress = progress
                                
                                if progress < 1 {
                                    if !isDownloadSheetPresented {
                                        isDownloadSheetPresented = true
                                    }
                                } else {
                                    isDownloadSheetPresented = false
                                }
                            },
                            
                            installProgressHandler: { progress in
                                installProgress = progress
                                
                                if progress < 1 {
                                    if !isInstallSheetPresented {
                                        isInstallSheetPresented = true
                                    }
                                } else {
                                    isInstallSheetPresented = false
                                }
                            },
                            
                            completion: { completion in
                                switch completion {
                                case .success:
                                    installComplete = true
                                case .failure:
                                    installError = true
                                }
                            }
                        )
                    }
                    .disabled(Libraries.isInstalled())
                    .buttonStyle(.borderedProminent)
                }
                
                HStack {
                    Button(action: { // TODO: implement question mark popover
                        isHelpPopoverPresented.toggle()
                    }, label: {
                        Image(systemName: "questionmark")
                            .controlSize(.small)
                    })
                    .clipShape(Circle())
                    .popover(isPresented: $isHelpPopoverPresented) {
                        VStack {
                            NotImplementedView()
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .fixedSize()
            .padding()
            
            // MARK: Download Sheet
            .sheet(isPresented: $isDownloadSheetPresented) {
                VStack {
                    Text("Downloading Game Porting Toolkit...")
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if downloadProgress > 0 {
                            Text("\(Int(downloadProgress * 100))%")
                        }
                        
                        if downloadProgress > 0 {
                            ProgressView(value: downloadProgress, total: 1)
                                .progressViewStyle(.linear)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
                .fixedSize()
                .interactiveDismissDisabled()
                
                .onDisappear {
                    if downloadProgress < 1 {
                        // TODO: add alert function to auto show alert
                    }
                }
            }
            
            // MARK: Install Sheet
            .sheet(isPresented: $isInstallSheetPresented) {
                VStack {
                    Text("Installing Game Porting Toolkit...")
                    
                    HStack {
                        Text("\(Int(installProgress * 100))%")
                        
                        ProgressView(value: installProgress, total: 1)
                            .progressViewStyle(.linear)
                    }
                }
                .padding()
                .fixedSize()
                
                .onDisappear {
                    // TODO: action if install is incomplete
                }
            }
            
            // MARK: - Other Properties
            
            .alert(isPresented: $isAlertPresented) {
                switch activeAlert {
                case .closeConfirmation:
                    // MARK: Close Confirmation Alert
                    Alert(
                        title: Text("Are you sure you want to cancel Mythic Engine (GPTK) installation?"),
                        message: Text("Doing this means you can only play macOS-supported games.\n")
                        + Text("(Don't worry, you can still install Mythic Engine later.)") // styling does nothing as of now -- call it future-proofing
                            .italic()
                            .font(.footnote)
                            .foregroundStyle(.placeholder),
                        primaryButton: .destructive(Text("OK")) { isPresented = false },
                        secondaryButton: .cancel(Text("Cancel")) { isAlertPresented = false }
                    )
                case .installError:
                    // MARK: Installation Error Alert
                    Alert(title: Text("Error installing GPTK."))
                }
            }
        }
    }
}

#Preview {
    // MARK: - Preview
    OnboardingView.InstallView(isPresented: .constant(true))
}
