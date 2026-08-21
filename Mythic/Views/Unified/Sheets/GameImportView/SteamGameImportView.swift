//
//  SteamGameImportView.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import OSLog

/**
 Adds a Steam title to the library by app ID.

 Unlike Epic, Steam cannot be asked what an account owns — `licenses_print` truncates its app list at 32
 entries per package and returns nothing at all anonymously, `appcache/appinfo.vdf` is binary, and the Web
 API needs a key plus a public profile. So titles are named explicitly here, and Mythic looks the app ID
 up to fill in everything else.

 Titles already downloaded through Mythic need no importing — the library picks them up from their app
 manifests on refresh.
 */
struct SteamGameImportView: View {
    @Bindable var gameDataStore: GameDataStore = .shared

    @Binding var isPresented: Bool

    @State private var appID: String = .init()
    @State private var resolvedInfo: ValveDataFormat.AppInfo?
    @State private var resolvedPlatforms: Set<Game.Platform> = .init()

    @State private var isSignInSheetPresented: Bool = false
    @State private var isResolving: Bool = false
    @State private var resolutionError: Error?

    private var trimmedAppID: String {
        appID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAppIDWellFormed: Bool {
        !trimmedAppID.isEmpty && trimmedAppID.allSatisfy(\.isNumber)
    }

    var body: some View {
        VStack {
            HStack {
                VStack {
                    if let resolvedInfo {
                        GameImageCard(game: SteamGame(appID: resolvedInfo.appID,
                                                      title: resolvedInfo.name,
                                                      installationState: .uninstalled),
                                      url: URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(resolvedInfo.appID)/library_600x900_2x.jpg"),
                                      isImageEmpty: .constant(false))
                        .aspectRatio(3/4, contentMode: .fit)
                    } else {
                        // Before an app ID resolves there is nothing to fetch, and asking the CDN for
                        // artwork anyway produced a "couldn't load the image" panel in the empty state.
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.quinary)
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "questionmark.square.dashed")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.tertiary)
                                    Text("Enter an app ID to look a title up.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                            }
                    }

                    Label("Artwork comes from Steam's CDN, keyed on the app ID.", systemImage: "info")
                        .symbolVariant(.circle)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .padding([.leading, .top])

                VStack {
                    Form {
                        Section {
                            HStack {
                                TextField("App ID", text: $appID, prompt: Text("e.g. 1623730"))
                                    .onSubmit(resolve)

                                Button("Look Up", action: resolve)
                                    .disabled(!isAppIDWellFormed)
                                    .disabled(isResolving)
                            }

                            if isResolving {
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("Asking Steam about \(trimmedAppID)…")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your library loads by itself once you're signed in. Use this for anything it missed.")
                                Text("Find it in the store page URL: store.steampowered.com/app/**1623730**/")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }

                        if let resolvedInfo {
                            Section {
                                LabeledContent("Title", value: resolvedInfo.name)

                                if let downloadSize = resolvedInfo.downloadSize {
                                    LabeledContent("Download",
                                                   value: downloadSize.formatted(.byteCount(style: .file)))
                                }

                                LabeledContent("Available for",
                                               value: resolvedPlatforms.isEmpty
                                               ? String(localized: "Unknown")
                                               : resolvedPlatforms
                                                    .map(\.description)
                                                    .sorted()
                                                    .joined(separator: ", "))
                            }
                        }

                        if !SteamCMD.isInstalled {
                            // Points at Accounts, not Settings: that is where SteamCMD is now set up, and
                            // it is the same screen where signing in happens.
                            Label("SteamCMD isn't installed yet — set it up in Accounts.",
                                  systemImage: "exclamationmark.triangle")
                            .symbolVariant(.fill)
                        } else if !Steam.isSignedIn {
                            // Actionable rather than informational: this is the step that makes the whole
                            // library appear, so the button belongs here rather than a pointer to Accounts.
                            Section {
                                Label("You aren't signed in to Steam. You can still add titles, but downloading needs an account.",
                                      systemImage: "person.crop.circle.badge.exclamationmark")

                                Button {
                                    isSignInSheetPresented = true
                                } label: {
                                    Label {
                                        Text("Connect Steam")
                                    } icon: {
                                        Image("Steam")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }

                Spacer()

                Button("Add to Library", action: addToLibrary)
                    .disabled(resolvedInfo == nil)
                    .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom])
        }
        .sheet(isPresented: $isSignInSheetPresented) {
            SteamSignInView(isPresented: $isSignInSheetPresented)
                .frame(width: 460)
        }
        .alert("Unable to look that app ID up.",
               isPresented: .init(get: { resolutionError != nil },
                                  set: { if !$0 { resolutionError = nil } }),
               presenting: resolutionError) { _ in
            Button("OK") { resolutionError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func resolve() {
        guard isAppIDWellFormed else { return }
        let appID = trimmedAppID

        Task {
            isResolving = true
            defer { isResolving = false }

            do {
                let info = try await Steam.refreshAppInfo(appID: appID)
                resolvedInfo = info
                resolvedPlatforms = Steam.supportedPlatforms(for: info)
            } catch {
                Logger.app.error("Steam app lookup failed for \(appID, privacy: .public): \(error.localizedDescription)")
                resolvedInfo = nil
                resolvedPlatforms = .init()
                resolutionError = error
            }
        }
    }

    private func addToLibrary() {
        guard let resolvedInfo else { return }

        // Inserted uninstalled, which is the state Epic titles arrive in from getInstallableGames();
        // the card's Install button takes it from here.
        gameDataStore.library.update(
            with: SteamGame(appID: resolvedInfo.appID,
                            title: resolvedInfo.name,
                            installationState: .uninstalled)
        )

        isPresented = false
    }
}

#Preview {
    SteamGameImportView(isPresented: .constant(true))
}
