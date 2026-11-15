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

import Foundation
import SwiftUI
import SemanticVersion

struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @ObservedObject private var updateController: SparkleUpdateController = .shared
    @Bindable private var operationManager: GameOperationManager = .shared

    @State private var appVersion: String = .init()
    @State private var buildNumber: Int = 0

    @State private var engineVersion: SemanticVersion?

    /// The sidebar's selected destination. Shared with menu bar commands through `FocusedValues`.
    @State private var selection: SidebarItem? = .home
    @State private var isGameImportSheetPresented: Bool = false

    /// Keep the Operations row visible while it's selected, even after the queue empties.
    private var isOperationsRowVisible: Bool {
        !operationManager.queue.isEmpty || selection == .operations
    }

    var body: some View {
        NavigationSplitView(
            sidebar: {
                List(selection: $selection) {
                    Section {
                        Label("Home", systemImage: "house")
                            .help("Everything in one place")
                            .tag(SidebarItem.home)

                        Label("Library", systemImage: "books.vertical")
                            .help("View your games")
                            .tag(SidebarItem.library)

                        Label("Store", systemImage: "bag")
                            .help("Purchase new games from Epic")
                            .tag(SidebarItem.store)
                    }

                    Section {
                        Label("Containers", systemImage: "cube")
                            .help("Manage containers for Windows® applications")
                            .tag(SidebarItem.containers)

                        Label("Accounts", systemImage: "person.2")
                            .help("View all currently signed in accounts")
                            .tag(SidebarItem.accounts)

                        // opens a separate window, so it's deliberately not a selectable destination.
                        // it's also reachable through the Help menu.
                        Button("Support", systemImage: "questionmark.bubble") {
                            SupportWindowController.show()
                        }
                        .help("Get support")
                        .buttonStyle(.plain)
                    } header: {
                        Text("Management")
                    }

                    if isOperationsRowVisible {
                        Section {
                            Label("Operations", systemImage: "progress.indicator")
                                .help("View all active game operations")
                                .badge(operationManager.queue.count)
                                .tag(SidebarItem.operations)
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 280)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    sidebarFooter
                }
            }, detail: {
                switch selection ?? .home {
                case .home:
                    HomeView()
                case .library:
                    LibraryView()
                case .store:
                    StoreView()
                case .containers:
                    ContainersView()
                case .accounts:
                    AccountsView()
                case .operations:
                    OperationsView()
                }
            }
        )
        .toolbar {
            ToolbarItem(placement: .status) {
                if !networkMonitor.isConnected {
                    Image(systemName: "network")
                        .symbolVariant(.slash)
                        .help("Mythic is not connected to the internet.")
                        .accessibilityLabel("Mythic is not connected to the internet.")
                }
            }
        }
        .sheet(isPresented: $isGameImportSheetPresented) {
            GameImportView(isPresented: $isGameImportSheetPresented)
                .fixedSize()
        }
        // expose navigation state to the menu bar (see `MythicCommands`)
        .focusedSceneValue(\.sidebarSelection, $selection)
        .focusedSceneValue(\.isGameImportSheetPresented, $isGameImportSheetPresented)
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
#if DEBUG
            VStack {
                if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                   let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                   let mythicVersion: SemanticVersion = .init("\(shortVersion)+\(bundleVersion)") {
                    Text("Mythic \(mythicVersion.prettyString)")
                }

                if let engineVersion {
                    Text("Mythic Engine \(engineVersion.prettyString)")
                }
            }
            .task { @MainActor in
                engineVersion = await Engine.installedVersion
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
#endif // DEBUG

            switch updateController.state {
            case .updateAvailable:
                updateBlock("Update Available", buttonText: "Show More") {
                    updateController.checkForUpdates(userInitiated: true)
                }
            case .readyToRelaunch(let acknowledgement):
                updateBlock("Update Ready", buttonText: "Relaunch") {
                    acknowledgement(.update)
                }
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func updateBlock(_ title: String, buttonText: String, action: @escaping () -> Void) -> some View {
        VStack {
            Label(title, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: action, label: {
                Text(buttonText)
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.borderedProminent)
            .clipShape(.capsule)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension ContentView {
    /// Destinations selectable from the main window's sidebar.
    enum SidebarItem: String, Hashable, CaseIterable, Sendable {
        case home
        case library
        case store
        case containers
        case accounts
        case operations
    }
}

// MARK: - Focused values

private struct SidebarSelectionFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<ContentView.SidebarItem?>
}

private struct GameImportSheetPresentationFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    /// The main window's sidebar selection, if the main window is showing its primary content.
    var sidebarSelection: Binding<ContentView.SidebarItem?>? {
        get { self[SidebarSelectionFocusedValueKey.self] }
        set { self[SidebarSelectionFocusedValueKey.self] = newValue }
    }

    /// Whether the main window's "Import Game" sheet is presented.
    var isGameImportSheetPresented: Binding<Bool>? {
        get { self[GameImportSheetPresentationFocusedValueKey.self] }
        set { self[GameImportSheetPresentationFocusedValueKey.self] = newValue }
    }
}

// MARK: - Menu bar commands

/// Menu bar commands, and their keyboard shortcuts, for navigating and acting on the main window.
struct MythicCommands: Commands {
    @FocusedValue(\.sidebarSelection) private var sidebarSelection
    @FocusedValue(\.isGameImportSheetPresented) private var isGameImportSheetPresented

    var body: some Commands {
        SidebarCommands()

        CommandGroup(after: .newItem) {
            Button("Import Game...") {
                isGameImportSheetPresented?.wrappedValue = true
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(isGameImportSheetPresented == nil)

            Button("Refresh Library") {
                Task(priority: .userInitiated) {
                    try? await GameDataStore.shared.refreshFromStorefronts()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(sidebarSelection == nil)
        }

        CommandGroup(before: .sidebar) {
            Button("Home") { sidebarSelection?.wrappedValue = .home }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Button("Library") { sidebarSelection?.wrappedValue = .library }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Button("Store") { sidebarSelection?.wrappedValue = .store }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Button("Containers") { sidebarSelection?.wrappedValue = .containers }
                .keyboardShortcut("4", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Button("Accounts") { sidebarSelection?.wrappedValue = .accounts }
                .keyboardShortcut("5", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Button("Operations") { sidebarSelection?.wrappedValue = .operations }
                .keyboardShortcut("6", modifiers: .command)
                .disabled(sidebarSelection == nil)

            Divider()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NetworkMonitor.shared)
}
