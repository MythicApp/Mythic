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
    @State private var activeAlert: ActiveAlert?
    @State private var isAlertPresented: Bool = false
    
    @ObservedObject private var variables: VariableManager = .shared
    @ObservedObject private var gameModification: GameModification = .shared
    
    @State var account: String = Legendary.whoAmI()
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0
    
    func updateEpicSignin() { account = Legendary.whoAmI() }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
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
                }
                
                Spacer()
                
                if let game = gameModification.game {
                    Divider()
                    
                    VStack {
                        Text((gameModification.type?.rawValue ?? "modifying").uppercased()) // FIXME: conditional
                            .fontWeight(.bold)
                            .font(.system(size: 8))
                            .offset(x: -2, y: 0)
                        Text(game.title)
                        
                        InstallationProgressView()
                    }
                }
                
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
                
                if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                   let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                   let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    Text("\(displayName) \(shortVersion) (\(bundleVersion))")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)
                }
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
                            activeAlert = .none
                        }
                    )
                case nil:
                    Logger.app.error("no activeAlert supplied. resultantly, there's no alert to be presented.")
                    return Alert(
                        title: .init("An error occurred."),
                        message: .init(
                            """
                            \(Text("[ActiveAlert Fault]").italic())
                            If this error appears, please consult support.
                            Make sure to include what you were doing when the error occured.
                            """
                        )
                    )
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150, idealWidth: 250, maxWidth: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleSidebar, label: {
                        Image(systemName: "sidebar.left")
                    })
                    .help("Toggle sidebar")
                }
                
                if !networkMonitor.isEpicAccessible {
                    ToolbarItem(placement: .navigation) {
                        if networkMonitor.isCheckingEpicAccessibility {
                            Image(systemName: "network.slash")
                                .foregroundStyle(.yellow)
                                .symbolEffect(.pulse)
                                .help("Mythic is checking the connection to Epic.")
                        } else if networkMonitor.isConnected {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundStyle(.yellow)
                                .symbolEffect(.pulse)
                                .help("Mythic is connected to the internet, but cannot establish a connection to Epic.")
                        } else {
                            Image(systemName: "network.slash")
                                .foregroundStyle(.red)
                                .help("Mythic is not connected to the internet.")
                        }
                    }
                }
            }
            
            HomeView()
        }
    }
}

// MARK: - Sidebar Toggle Function
func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}

// MARK: - Preview
#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
