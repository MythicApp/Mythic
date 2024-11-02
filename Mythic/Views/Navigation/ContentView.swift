//
//  ContentView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/9/2023.
//
//  Reference
//  https://github.com/1998code/SwiftUI2-MacSidebar
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Foundation
import OSLog
import Combine

// MARK: - ContentView Struct
struct ContentView: View {
    
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var sparkle: SparkleController
    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var operation: GameOperation = .shared
    
    @State private var isInstallStatusViewPresented: Bool = false
    
    @State var account: String = Legendary.whoAmI()
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0
    
    func updateEpicSignin() { account = Legendary.whoAmI() }
    
    // MARK: - Body
    var body: some View {
        NavigationSplitView(
            sidebar: {
                List {
                    Section {
                        NavigationLink(destination: HomeView()) {
                            Label("Home", systemImage: "house")
                            // .foregroundStyle(.primary)
                                .help("Everything in one place")
                        }
                        
                        NavigationLink(destination: LibraryView()) {
                            Label("Library", systemImage: "books.vertical")
                            // .foregroundStyle(.primary)
                                .help("View your games")
                        }
                        
                        NavigationLink(destination: StoreView()) {
                            Label("Store", systemImage: "basket")
                            // .foregroundStyle(.primary)
                                .help("Purchase new games from Epic")
                        }
                    } header: {
                        Text("Dashboard")
                    }
                    
                    Spacer()
                    
                    Section {
                        NavigationLink(destination: ContainersView()) {
                            Label("Containers", systemImage: "cube")
                            // .foregroundStyle(.primary)
                                .help("Manage containers for Windows® applications")
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                            // .foregroundStyle(.primary)
                                .help("Configure Mythic")
                        }
                        
                        NavigationLink(destination: SupportView()) {
                            Label("Support", systemImage: "questionmark.bubble")
                            // .foregroundStyle(.primary)
                                .help("Get support/Support Mythic")
                        }
                        
                        NavigationLink(destination: AccountsView()) {
                            Label("Accounts", systemImage: "person.2")
                            // .foregroundStyle(.primary)
                                .help("View all currently signed in accounts")
                        }
                    } header: {
                        Text("Management")
                    }
                }
                
                .sheet(isPresented: $isInstallStatusViewPresented) {
                    InstallStatusView(isPresented: $isInstallStatusViewPresented)
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 150, idealWidth: 250, maxWidth: 300)
                .toolbar {
                    if !networkMonitor.isEpicAccessible {
                        ToolbarItem(placement: .navigation) {
                            if networkMonitor.isCheckingEpicAccessibility {
                                Image(systemName: "network.slash")
                                    .symbolEffect(.pulse)
                                    .help("Mythic is checking the connection to Epic.")
                            } else if networkMonitor.isConnected {
                                Image(systemName: "wifi.exclamationmark")
                                    .symbolEffect(.pulse)
                                    .help("Mythic is connected to the internet, but cannot establish a connection to Epic.")
                            } else {
                                Image(systemName: "network.slash")
                                    .help("Mythic is not connected to the internet.")
                            }
                        }
                    }
                }
                
                if operation.current != nil || !operation.queue.isEmpty {
                    List {
                        NavigationLink(destination: DownloadsEvo()) {
                            Label("Downloads", systemImage: "arrow.down.to.line")
                            // .foregroundStyle(.primary)
                                .help("View all downloads")
                        }
                    }
                    .frame(maxHeight: 40)
                }
                
#if DEBUG
                VStack {
                    if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                       let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        Text("\(displayName) \(shortVersion) (\(bundleVersion))")
                    }
                    
                    if let engineVersion = Engine.version {
                        Text("Mythic Engine \(engineVersion.major).\(engineVersion.minor).\(engineVersion.patch) (\(engineVersion.build))")
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
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(NetworkMonitor())
        .environmentObject(SparkleController())
}
