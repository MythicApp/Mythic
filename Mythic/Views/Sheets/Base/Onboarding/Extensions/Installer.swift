//
//  Install.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Combine

extension OnboardingView {
    // MARK: - InstallView Struct
    /// A view guiding the user through the installation of the Game Porting Toolkit.
    struct InstallView: View {
        
        // MARK: - Binding Variables
        @Binding var isPresented: Bool
        
        // MARK: - Enumerations
        // swiftlint:disable nesting
        enum ActiveAlert {
            case closeConfirmation,
                 installError
        }
        // swiftlint:enable nesting
        
        // MARK: - State Variables
        @State private var isDownloadSheetPresented: Bool = false
        @State private var isInstallSheetPresented: Bool = false
        @State private var activeAlert: ActiveAlert = .closeConfirmation
        @State private var isAlertPresented: Bool = false
        @State private var downloadProgressEstimate: Double = 0
        @State private var installProgress: Double = 0
        @State private var installComplete: Bool = false
        @State private var installError: Bool = false
        
        // MARK: - Body
        var body: some View {
            VStack {
                // MARK: Title Text
                Text("Install Game Porting Toolkit")
                    .font(.title)
                
                // MARK: Divider
                Divider()
                
                // MARK: Installation Instructions
                Text("In order to launch windows games, Mythic must download"
                     + "\na special translator by Apple to convert Windows code to macOS."
                     + "\n"
                     + "\nIt's around 1.8GB in size, but the download is around 600MB due to compression."
                )
                .multilineTextAlignment(.center)
                
                // MARK: Action Buttons
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
                                downloadProgressEstimate = progress
                                
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
            }
            .padding()
            
            // MARK: Download Sheet
            .sheet(isPresented: $isDownloadSheetPresented) {
                VStack {
                    // MARK: Downloading Text
                    Text("Downloading Game Porting Toolkit...")
                        .multilineTextAlignment(.leading)
                    
                    // MARK: Download Progress
                    HStack {
                        if downloadProgressEstimate > 0 {
                            Text("\(Int(downloadProgressEstimate * 100))%")
                        }
                        
                        if downloadProgressEstimate > 0 {
                            ProgressView(value: downloadProgressEstimate, total: 1)
                                .progressViewStyle(.linear)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
                .fixedSize()
                
                // MARK: Action on Disappear
                .onDisappear {
                    // TODO: action if download is incomplete
                }
            }
            
            // MARK: Install Sheet
            .sheet(isPresented: $isInstallSheetPresented) {
                VStack {
                    // MARK: Installing Text
                    Text("Installing Game Porting Toolkit...")
                        .multilineTextAlignment(.leading)
                    
                    // MARK: Install Progress
                    HStack {
                        Text("\(Int(installProgress * 100))%")
                        
                        ProgressView(value: installProgress, total: 1)
                            .progressViewStyle(.linear)
                    }
                }
                .padding()
                .fixedSize()
                
                // MARK: Action on Disappear
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
                        title: Text("Are you sure you want to cancel GPTK installation?"),
                        message: Text("Doing this means you can only play macOS-supported games, imported games, or use Whisky."),
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
