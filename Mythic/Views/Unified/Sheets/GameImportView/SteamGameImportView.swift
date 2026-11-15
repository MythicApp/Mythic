//
//  SteamGameImportView.swift
//  Mythic
//

import SwiftUI

struct SteamGameImportView: View {
    private struct LocationGroup: Identifiable {
        let location: SteamClient.InstallLocation
        let games: [SteamClient.InstalledApp]

        var id: SteamClient.InstallLocation { location }
        var locationName: String { location.containerURL?.lastPathComponent ?? "macOS Steam" }
    }

    @Binding var isPresented: Bool

    @State private var isRefreshing = false
    @State private var errorDescription: String?
    @State private var isErrorAlertPresented = false

    private var gamesByLocation: [LocationGroup] {
        let groupedGames = Dictionary(grouping: SteamClient.installedApps(), by: \.location)
        return groupedGames.map { location, games in
            LocationGroup(location: location, games: games.sorted { $0.name < $1.name })
        }
        .sorted { $0.locationName.localizedStandardCompare($1.locationName) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installed Steam games are added to your library automatically.")
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)

            List {
                if gamesByLocation.isEmpty {
                    ContentUnavailableView(
                        "No Installed Steam Games",
                        systemImage: "gamecontroller",
                        description: Text("Installed games will appear here automatically.")
                    )
                } else {
                    ForEach(gamesByLocation) { group in
                        Section(group.locationName) {
                            ForEach(group.games, id: \.appID) { game in
                                Text(game.name)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }

                Spacer()

                Button {
                    Task {
                        isRefreshing = true
                        defer { isRefreshing = false }
                        do {
                            try await GameDataStore.shared.refreshFromStorefronts(.steam)
                        } catch {
                            errorDescription = error.localizedDescription
                            isErrorAlertPresented = true
                        }
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Refresh")
                    }
                }
                .disabled(isRefreshing)
                .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom])
        }
        .alert("Unable to refresh Steam games.",
               isPresented: $isErrorAlertPresented,
               presenting: errorDescription) { _ in
            Button("OK", role: .cancel) {}
        } message: { description in
            Text(description)
        }
    }
}

#Preview {
    SteamGameImportView(isPresented: .constant(true))
}
