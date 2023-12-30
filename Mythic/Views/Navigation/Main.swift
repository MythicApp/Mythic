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
import CachedAsyncImage

// MARK: - MainView Struct
struct MainView: View {
    
    // MARK: - State Variables
    @State private var isAuthViewPresented: Bool = false
    @State private var isInstallStatusViewPresented: Bool = false
    
    enum ActiveAlert {
        case stopDownloadWarning
        case signOutConfirmation
    }
    @State private var activeAlert: ActiveAlert? = .none
    @State private var isAlertPresented: Bool = false
    
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var epicUserAsync: String = "Loading..."
    @State private var signedIn: Bool = false
    
    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0
    
    // MARK: - Functions
    func updateLegendaryAccountState() {
        epicUserAsync = "Loading..."
        DispatchQueue.global(qos: .userInitiated).async {
            let whoAmIOutput = Legendary.whoAmI()
            DispatchQueue.main.async { [self] in
                signedIn = Legendary.signedIn()
                epicUserAsync = whoAmIOutput
            }
        }
    }
    
    // MARK: - Initializer
    init() { updateLegendaryAccountState() }
    
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
                    }
                    NavigationLink(destination: LibraryView()) {
                        Label("Library", systemImage: "books.vertical")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink(destination: StoreView()) {
                        Label("Store", systemImage: "basket")
                            .foregroundStyle(.primary)
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
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink(destination: SupportView()) {
                        Label("Support", systemImage: "questionmark.bubble")
                            .foregroundStyle(.primary)
                    }
                }
                
                Spacer()
                
                if let installingGame: Legendary.Game = variables.getVariable("installing") {
                    Divider()
                    
                    VStack {
                        Text("INSTALLING")
                            .fontWeight(.bold)
                            .font(.system(size: 8))
                            .offset(x: -2, y: 0)
                        Text(installingGame.title)
                        
                        HStack {
                            Button {
                                isInstallStatusViewPresented = true
                            } label: {
                                if let installStatus: [String: [String: Any]] = variables.getVariable("installStatus"),
                                   let percentage: Double = (installStatus["progress"])?["percentage"] as? Double { // FIXME: installing migration
                                    ProgressView(value: percentage, total: 100)
                                        .progressViewStyle(.linear)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(.linear)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                activeAlert = .stopDownloadWarning
                                isAlertPresented = true
                            } label: {
                                Image(systemName: "stop.fill")
                                    .foregroundStyle(.red)
                                    .padding()
                            }
                            .shadow(color: .red, radius: 10, x: 1, y: 1)
                            .buttonStyle(.plain)
                            .frame(width: 8, height: 8)
                            .controlSize(.mini)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "person")
                        .foregroundStyle(.primary)
                    Text(epicUserAsync)
                        .onAppear {
                            updateLegendaryAccountState()
                        }
                }
                
                if epicUserAsync != "Loading..." {
                    if signedIn {
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
                            NSWorkspace.shared.open(URL(string: "http://legendary.gl/epiclogin")!)
                            isAuthViewPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "person")
                                    .foregroundStyle(.primary)
                                Text("Sign In")
                            }
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
                    .onDisappear {
                        updateLegendaryAccountState()
                    }
            }
            
            .sheet(isPresented: $isInstallStatusViewPresented) {
                InstallStatusView(isPresented: $isInstallStatusViewPresented)
            }
            .alert(isPresented: $isAlertPresented) {
                switch activeAlert {
                case .stopDownloadWarning:
                    return stopDownloadAlert(isPresented: $isAlertPresented, game: variables.getVariable("installing")) // FIXME: installing migration
                case .signOutConfirmation:
                    return Alert(
                        title: .init("Are you sure you want to sign out?"),
                        message: .init("This will sign you out of the account \"\(Legendary.whoAmI())\"."),
                        primaryButton: .destructive(.init("Sign Out")) {
                            Task(priority: .high) { // TODO: possible progress view implementation
                                let command = await Legendary.command(args: ["auth", "--delete"], useCache: false, identifier: "userAreaSignOut")
                                if let commandStderrString = String(data: command.stderr, encoding: .utf8), commandStderrString.contains("User data deleted.") {
                                    updateLegendaryAccountState()
                                }
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
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar, label: {
                        Image(systemName: "sidebar.left")
                    })
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
}
