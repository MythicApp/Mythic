//
//  SparkleUpdaterSheetViewModifier.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Sparkle

public struct SparkleUpdaterSheetViewModifier: ViewModifier {
    @ObservedObject private var updateController = SparkleUpdateControllerModel.shared
    @State private var checkingForUpdatesSheetPresented = false
    @State private var noUpdateAvailableAlertPresented = false
    @State private var updateAvailableSheetPresented = false
    @State private var downloadSheetPresented = false
    @State private var extractSheetPresented = false
    @State private var restartSheetPresented = false
    @State private var errorSheetPresented = false

    private var updateAvailableAppcast: SUAppcastItem {
        if case .updateAvailable(_, let appcast) = updateController.state {
            return appcast
        }
        return .empty()
    }
    private var downloadProgress: (started: Date, total: UInt64, completed: UInt64) { // swiftlint:disable:this large_tuple
        if case .downloadingUpdate(_, let progress) = updateController.state {
            return (progress.started, progress.total, progress.completed)
        }
        return (.init(), 0, 0)
    }
    private var extractProgress: (started: Date, progress: Double) {
        if case .extractingUpdate(let progress) = updateController.state {
            return (progress.started, progress.progress)
        }
        return (.init(), 0)
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $checkingForUpdatesSheetPresented) {
                SparkleUpdaterCheckingView(cancel: {
                    if case .checkingForUpdates(let cancel) = updateController.state {
                        cancel()
                    }
                })
            }
            .alert("No Update Available",
                   isPresented: $noUpdateAvailableAlertPresented,
                   actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(String(format: String(localized: "You are on the latest available version of %@, %@."),
                            AppDelegate.applicationBundleName,
                            "v" + AppDelegate.applicationVersion.description))
            })
            .sheet(isPresented: $updateAvailableSheetPresented) {
                SparkleUpdaterPreviewView(appcast: updateAvailableAppcast, choice: { choiceValue in
                    if case .updateAvailable(let choice, _) = updateController.state {
                        choice(choiceValue)
                    }
                })
            }
            .sheet(isPresented: $downloadSheetPresented) {
               SparkleUpdaterDownloadingView(cancel: {
                    if case .downloadingUpdate(let cancel, _) = updateController.state {
                        cancel()
                    }
                }, downloadStartTimestamp: downloadProgress.started, bytesDownloaded: downloadProgress.completed, bytesTotal: downloadProgress.total)
            }
            .sheet(isPresented: $extractSheetPresented) {
                SparkleUpdaterExtractingView(progress: extractProgress.progress)
            }
            .sheet(isPresented: $restartSheetPresented) {
                SparkleUpdaterFinishView(dismiss: { relaunch in
                    if case .readyToRelaunch(let acknowledge) = updateController.state {
                        acknowledge(relaunch ? .update : .dismiss)
                    }
                })
            }
            .alert("Update Error",
                   isPresented: $errorSheetPresented,
                   actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                if case .error(_, let error) = updateController.state {
                    Text(error.localizedDescription)
                }
            })
            .onChange(of: noUpdateAvailableAlertPresented) {
                if case .noUpdateAvailable(let acknowledge) = updateController.state,
                     !noUpdateAvailableAlertPresented {
                    acknowledge()
                }
            }
            .onChange(of: errorSheetPresented) {
                if case .error(let acknowledge, _) = updateController.state,
                     !errorSheetPresented {
                    acknowledge()
                }
            }
            .onChange(of: updateController.state.stateType) {
                updateState()
            }
            .onChange(of: updateController.userInitiatedCheck) {
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
        
        if !updateController.userInitiatedCheck { return }

        switch updateController.state {
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
