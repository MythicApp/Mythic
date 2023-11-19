//
//  Install.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

import SwiftUI
import Combine

extension OnboardingView {
    struct InstallView: View {
        @Binding var isPresented: Bool

        // @AppStorage("alreadyShownCloseConfirmation") var alreadyShownCloseConfirmation: Bool = false

        @State private var isDownloadSheetPresented: Bool = false
        @State private var isInstallSheetPresented: Bool = false

        enum ActiveAlert { case closeConfirmation, installError }
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
                                }
                                else { isDownloadSheetPresented = false }
                            },
                            installProgressHandler: { progress in
                                installProgress = progress

                                if progress < 1 {
                                    if !isInstallSheetPresented {
                                        isInstallSheetPresented = true
                                    }
                                }
                                else { isInstallSheetPresented = false }
                            },
                            completion: { completion in
                                switch completion {
                                case .success(_):
                                    installComplete = true
                                case .failure(_):
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
                        Text("\(Int(downloadProgressEstimate * 100))%")

                        ProgressView(value: downloadProgressEstimate, total: 1)
                            .progressViewStyle(.linear)
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
