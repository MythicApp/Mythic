//
//  SparkleUpdaterSheetViewModifier.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import Sparkle

struct SparkleUpdater: ViewModifier {
    @ObservedObject private var controller: SparkleUpdateController = .shared
    
    @State private var checkingForUpdatesSheetPresented: Bool = false
    @State private var noUpdateAvailableAlertPresented: Bool = false
    @State private var updateAvailableSheetPresented: Bool = false
    @State private var downloadSheetPresented: Bool = false
    @State private var extractSheetPresented: Bool = false
    @State private var restartSheetPresented: Bool = false
    @State private var errorSheetPresented: Bool = false

    private var updateAvailableAppcast: SUAppcastItem {
        if case .updateAvailable(_, let appcast) = controller.state {
            return appcast
        }
        return .empty()
    }

    private var downloadProgress: (started: Date, total: UInt64, completed: UInt64) { // swiftlint:disable:this large_tuple
        if case .downloadingUpdate(_, let progress) = controller.state {
            return (progress.started, progress.total, progress.completed)
        }
        return (.init(), 0, 0)
    }

    private var extractProgress: (started: Date, progress: Double) {
        if case .extractingUpdate(let progress) = controller.state {
            return (progress.started, progress.progress)
        }
        return (.init(), 0)
    }
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $checkingForUpdatesSheetPresented) {
                CheckingView {
                    if case .checkingForUpdates(let cancel) = controller.state {
                        cancel()
                    }
                }
            }
            .alert(
                "No Update Available",
                isPresented: $noUpdateAvailableAlertPresented,
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text("You are on the latest available version of \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"), \(Mythic.appVersion?.description ?? "Unknown").")
                }
            )
            .sheet(isPresented: $updateAvailableSheetPresented) {
                PreviewView(appcast: updateAvailableAppcast) { choiceValue in
                    if case .updateAvailable(let choice, _) = controller.state {
                        choice(choiceValue)
                    }
                }
            }
            .sheet(isPresented: $downloadSheetPresented) {
                DownloadingView(
                    cancel: {
                        if case .downloadingUpdate(let cancel, _) = controller.state {
                            cancel()
                        }
                    },
                    downloadStartTimestamp: downloadProgress.started,
                    bytesDownloaded: downloadProgress.completed,
                    bytesTotal: downloadProgress.total
                )
            }
            .sheet(isPresented: $extractSheetPresented) {
                ExtractingView(progress: extractProgress.progress)
            }
            .sheet(isPresented: $restartSheetPresented) {
                FinishView { relaunch in
                    if case .readyToRelaunch(let acknowledge) = controller.state {
                        acknowledge(relaunch ? .update : .dismiss)
                    }
                }
            }
            .alert(
                "Update Error",
                isPresented: $errorSheetPresented,
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    if case .error(_, let error) = controller.state {
                        Text(error.localizedDescription)
                    }
                }
            )
            .onChange(of: noUpdateAvailableAlertPresented) {
                if case .noUpdateAvailable(let acknowledge) = controller.state, !noUpdateAvailableAlertPresented {
                    acknowledge()
                }
            }
            .onChange(of: errorSheetPresented) {
                if case .error(let acknowledge, _) = controller.state, !errorSheetPresented {
                    acknowledge()
                }
            }
            .onChange(of: controller.state.stateType) {
                updateState()
            }
            .onChange(of: controller.userInitiatedCheck) {
                updateState()
            }
    }
    
    func updateState() {
        checkingForUpdatesSheetPresented = false
        noUpdateAvailableAlertPresented = false
        updateAvailableSheetPresented = false
        downloadSheetPresented = false
        extractSheetPresented = false
        restartSheetPresented = false
        
        if !controller.userInitiatedCheck { return }

        switch controller.state {
        case .checkingForUpdates:
            checkingForUpdatesSheetPresented = true
        case .noUpdateAvailable:
            noUpdateAvailableAlertPresented = true
        case .updateAvailable:
            updateAvailableSheetPresented = true
        case .initializingUpdate, .downloadingUpdate:
            downloadSheetPresented = true
        case .extractingUpdate:
            extractSheetPresented = true
        case .readyToRelaunch:
            restartSheetPresented = true
        case .error:
            errorSheetPresented = true
        default:
            break
        }
    }
}
