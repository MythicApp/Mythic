//
//  ContentView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 8/9/2023.
//
//  Reference
//  https://github.com/1998code/SwiftUI2-MacSidebar
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Foundation
import OSLog
import Combine
import WhatsNewKit
import SemanticVersion

// MARK: - ContentView Struct
struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var sparkleController: SparkleController

    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var operation: GameOperation = .shared
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0
    
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

                        NavigationLink(destination: SupportView()) {
                            Label("Support", systemImage: "questionmark.bubble")
                                .help("Get support/Support Mythic")
                        }

                        NavigationLink(destination: AccountsView()) {
                            Label("Accounts", systemImage: "person.2")
                                .help("View all currently signed in accounts")
                        }
                    } header: {
                        Text("Management")
                    }
                }

                if operation.current != nil || !operation.queue.isEmpty {
                    List {
                        NavigationLink(destination: DownloadsEvo()) {
                            Label("Downloads", systemImage: "arrow.down.to.line")
                                .help("View all downloads")
                        }
                    }
                    .frame(maxHeight: 40)
                }

#if DEBUG
                VStack {
                    if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                       let mythicVersion: SemanticVersion = .init("\(shortVersion)+\(bundleVersion)") {
                        Text("Mythic \(mythicVersion.prettyString)")
                    }

                    if let engineVersion = Engine.version {
                        Text("Mythic Engine \(engineVersion.prettyString)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.placeholder)
                .padding(.bottom)
#endif
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
                        Image(systemName: "exclamationmark.icloud")
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
        .environmentObject(SparkleController())
}
