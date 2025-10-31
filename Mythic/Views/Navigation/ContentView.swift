//
//  ContentView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 8/9/2023.
//
//  Reference
//  https://github.com/1998code/SwiftUI2-MacSidebar
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Foundation
import OSLog
import Combine
import WhatsNewKit
import SemanticVersion

// MARK: - ContentView Struct
struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @ObservedObject private var updateController: SparkleUpdateControllerModel = .shared
    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var operation: GameOperation = .shared
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0

    @State private var engineVersion: SemanticVersion?

    // MARK: - Body
    var body: some View {
        NavigationSplitView(
            sidebar: {
                List {
                    Section {
                        NavigationLink(destination: HomeView()) {
                            Label("Home", systemImage: "house")
                                .help("Everything in one place")
                        }

                        NavigationLink(destination: LibraryView()) {
                            Label("Library", systemImage: "books.vertical")
                                .help("View your games")
                        }

                        NavigationLink(destination: StoreView()) {
                            Label("Store", systemImage: "basket")
                                .help("Purchase new games from Epic")
                        }
                    } header: {
                        Text("Dashboard")
                    }

                    Spacer()

                    Section {
                        NavigationLink(destination: ContainersView()) {
                            Label("Containers", systemImage: "cube")
                                .help("Manage containers for Windows® applications")
                        }

                        Button("Support", systemImage: "questionmark.bubble") {
                            SupportWindowController.show()
                        }
                        .help("Get support")
                        .buttonStyle(.plain)

                        NavigationLink(destination: AccountsView()) {
                            Label("Accounts", systemImage: "person.2")
                                .help("View all currently signed in accounts")
                        }
                    } header: {
                        Text("Management")
                    }
                }

                if operation.current != nil || !operation.queue.isEmpty {
                    List { // must wrap in a list to have the same styling as the other links
                        NavigationLink(destination: DownloadsEvo()) {
                            Label("Downloads", systemImage: "arrow.down.to.line")
                                .help("View all downloads")
                        }
                    }
                    .frame(maxHeight: 40)
                    .scrollDisabled(true)
                    .scrollIndicators(.hidden)
                }

#if DEBUG
                VStack {
                    if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                       let mythicVersion: SemanticVersion = .init("\(shortVersion)+\(bundleVersion)") {
                        Text("Mythic \(mythicVersion.prettyString)")
                    }

                    if let engineVersion = engineVersion {
                        Text("Mythic Engine \(engineVersion.prettyString)")
                    }
                }
                .task { @MainActor in
                    engineVersion = await Engine.installedVersion
                }
                .font(.footnote)
                .foregroundStyle(.placeholder)
                .padding(.bottom)
#endif // DEBUG
                switch updateController.state {
                case .updateAvailable:
                    VStack(alignment: .center, spacing: 4) {
                        Text("Update Available")
                            .font(.footnote)
                            .foregroundStyle(.placeholder)
                        Button {
                            updateController.checkForUpdates(userInitiated: true)
                        } label: {
                            Text("Show More")
                                .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.borderedProminent)
                            .clipShape(.capsule)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                case .readyToRelaunch(let acknowledge):
                    VStack(alignment: .center, spacing: 4) {
                        Text("Update Ready")
                            .font(.footnote)
                            .foregroundStyle(.placeholder)
                        Button {
                            acknowledge(.update)
                        } label: {
                            Text("Relaunch")
                                .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.borderedProminent)
                            .clipShape(.capsule)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                default: EmptyView()
                }
            }, detail: {
                HomeView()
            }
        )
        .whatsNewSheet()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !networkMonitor.isConnected {
                    switch networkMonitor.epicAccessibilityState {
                    case .accessible:
                        Image(systemName: "bolt.horizontal.fill")
                            .help("""
                            Mythic is connected to the internet,
                            but is unable to verify the connection to Epic Games.
                            """)
                    case .checking, .none:
                        Image(systemName: "network")
                            .symbolVariant(.slash)
                            .symbolEffect(.pulse)
                            .help("Mythic is verifying the connection to Epic Games.")
                    case .inaccessible:
                        Image(systemName: "network")
                            .symbolVariant(.slash)
                            .help("Mythic is not connected to the internet.")
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(NetworkMonitor.shared)
}
