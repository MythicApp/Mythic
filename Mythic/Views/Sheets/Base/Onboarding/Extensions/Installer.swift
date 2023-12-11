//
//  Install.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Combine

extension OnboardingView {
    enum ActiveAlert { case closeConfirmation, installError }
    
    struct InstallView: View {
        @Binding var isPresented: Bool
        
        // @AppStorage("alreadyShownCloseConfirmation") var alreadyShownCloseConfirmation: Bool = false
        
        @State private var isDownloadSheetPresented: Bool = false
        @State private var isInstallSheetPresented: Bool = false
        
        @State private var activeAlert: ActiveAlert = .closeConfirmation
        @State private var isAlertPresented: Bool = false
        
        @State private var downloadProgressEstimate: Double = 0
        @State private var installProgress: Double = 0
        @State private var installComplete: Bool = false
        @State private var installError: Bool = false
        
        var body: some View {
            VStack {
                Text("Install Game Porting Toolkit")
                    .font(.title)
                
                Divider()
                
                Text("In order to launch windows games, Mythic must download"
                     + "\na special translator by Apple to convert Windows code to macOS."
                     + "\n"
                     + "\nIt's around 1.8GB in size, but the download is around 600MB due to compression."
                )
                .multilineTextAlignment(.center)
                
                HStack {
                    Button("Close") {
                        if /* alreadyShownCloseConfirmation == false || */ Libraries.isInstalled() == false {
                            // alreadyShownCloseConfirmation = true
                            activeAlert = .closeConfirmation
                            isAlertPresented = true
                        } else {
                            isPresented = false
                        }
                    }
                    
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
            
            .sheet(isPresented: $isDownloadSheetPresented) {
                VStack {
                    Text("Downloading Game Porting Toolkit...")
                        .multilineTextAlignment(.leading)
                    
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
                
                .onDisappear {
                    // implement action if download incomplete
                }
            }
            
            .sheet(isPresented: $isInstallSheetPresented) {
                VStack {
                    Text("Installing Game Porting Toolkit...")
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("\(Int(installProgress * 100))%")
                        
                        ProgressView(value: installProgress, total: 1)
                            .progressViewStyle(.linear)
                    }
                }
                .padding()
                .fixedSize()
                
                .onDisappear {
                    // implement action if install incomplete
                }
            }
            
            .alert(isPresented: $isAlertPresented) {
                switch activeAlert {
                case .closeConfirmation:
                    Alert(
                        title: Text("Are you sure you want to cancel GPTK installation?"),
                        message: Text("Doing this means you can only play macOS-supported games, imported games, or use Whisky."),
                        primaryButton: .destructive(Text("OK")) { isPresented = false },
                        secondaryButton: .cancel(Text("Cancel")) { isAlertPresented = false }
                    )
                case .installError:
                    Alert(title: Text("Error installing GPTK."))
                }
            }
        }
    }
}

#Preview {
    OnboardingView.InstallView(isPresented: .constant(true))
}
