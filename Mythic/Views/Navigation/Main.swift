//
//  Main.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/9/2023.
//
//  Reference
//  https://github.com/1998code/SwiftUI2-MacSidebar
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Foundation
import OSLog
import Combine

// MARK: - MainView Struct
struct MainView: View {
    
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    // MARK: - State Variables
    @State private var isAuthViewPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    
    enum ActiveAlert {
        case signOutConfirmation
    }
    @State private var activeAlert: ActiveAlert = .signOutConfirmation
    @State private var isAlertPresented: Bool = false
    
    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var gameModification: GameModification = .shared
    
    @State var account: String = Legendary.whoAmI()
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0
    
    func updateEpicSignin() { account = Legendary.whoAmI() }
    
    // MARK: - Body
    var body: some View {
        NavigationSplitView(
            sidebar: {
                List {
                    Text("DASHBOARD")
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                    
                    Group {
                        NavigationLink(destination: HomeView()) {
                            Label("Home", systemImage: "house")
                                .foregroundStyle(.primary)
                                .help("Everything in one place")
                        }
                        
                        NavigationLink(destination: LibraryView()) {
                            Label("Library", systemImage: "books.vertical")
                                .foregroundStyle(.primary)
                                .help("View your games")
                        }
                        
                        NavigationLink(destination: StoreView()) {
                            Label("Store", systemImage: "basket")
                                .foregroundStyle(.primary)
                                .help("Purchase new games from Epic")
                        }
                    }
                    
                    Spacer()
                    
                    Text("MANAGEMENT")
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                    
                    Group {
                        NavigationLink(destination: WineView()) {
                            Label("Wine", systemImage: "wineglass")
                                .foregroundStyle(.primary)
                                .help("Manage containers for Windows® applications")
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                                .foregroundStyle(.primary)
                                .help("Configure Mythic")
                        }
                        
                        NavigationLink(destination: SupportView()) {
                            Label("Support", systemImage: "questionmark.bubble")
                                .foregroundStyle(.primary)
                                .help("Get support/Support Mythic")
                        }
                        
                        NavigationLink(destination: AccountsView()) {
                            Label("Accounts", systemImage: "person.2")
                                .foregroundStyle(.primary)
                                .help("Get support/Support Mythic")
                        }
                    }
                    /*
                     Spacer()
                     
                     
                     Divider()
                     
                     HStack {
                     Image(systemName: "person")
                     .foregroundStyle(.primary)
                     Text(account)
                     }
                     
                     if account != "Nobody" {
                     Button {
                     activeAlert = .signOutConfirmation
                     isAlertPresented = true
                     } label: {
                     HStack {
                     Image(systemName: "person.slash")
                     .foregroundStyle(.primary)
                     Text("Sign Out")
                     }
                     }
                     } else {
                     Button {
                     workspace.open(URL(string: "http://legendary.gl/epiclogin")!)
                     isAuthViewPresented = true
                     } label: {
                     HStack {
                     Image(systemName: "person")
                     .foregroundStyle(.primary)
                     Text("Sign In")
                     }
                     }
                     }
                     */
                }
                .sheet(isPresented: $isAuthViewPresented) {
                    AuthView(isPresented: $isAuthViewPresented)
                        .onDisappear { updateEpicSignin() }
                }
                
                .sheet(isPresented: $isInstallStatusViewPresented) {
                    InstallStatusView(isPresented: $isInstallStatusViewPresented)
                }
                .alert(isPresented: $isAlertPresented) {
                    switch activeAlert {
                    case .signOutConfirmation:
                        return Alert(
                            title: .init("Are you sure you want to sign out?"),
                            message: .init("This will sign you out of the account \"\(Legendary.whoAmI())\"."),
                            primaryButton: .destructive(.init("Sign Out")) {
                                Task(priority: .high) {
                                    await Legendary.command(
                                        args: ["auth", "--delete"],
                                        useCache: false,
                                        identifier: "userAreaSignOut"
                                    )
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel")) {
                                isAlertPresented = false
                            }
                        )
                    }
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
                
                if gameModification.game != nil {
                    List {
                        NavigationLink(destination: EmptyView()) {
                            Label("Downloads", systemImage: "arrow.down.to.line")
                                .foregroundStyle(.primary)
                                .help("Get support/Support Mythic")
                        }
                    }
                    .frame(maxHeight: 40)
                }
                
                if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                   let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                   let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    Text("\(displayName) \(shortVersion) (\(bundleVersion))")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)
                        .padding(.bottom)
                }
            }, detail: {
                HomeView()
            }
        )
    }
}

// MARK: - Preview
#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
