//
//  SupportView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Shimmer
import SwordRPC

struct SupportView: View {
    @Environment(\.colorScheme) var colorScheme

    private var colorSchemeValue: String {
        switch colorScheme {
        case .light: return "light"
        case .dark: return "dark"
        @unknown default: return "dark"
        }
    }

    var body: some View {
        HStack {
            VStack {
                WebView(
                    url: .init(string: "https://discord.com/widget?id=1154998702650425397&theme=\(colorSchemeValue)")!,
                    error: .constant(nil)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 10))

            VStack {
                if let patreonURL: URL = .init(string: /* temp comment "https://patreon.com/mythicapp" */ "https://ko-fi.com/vapidinfinity") {
                    WebView(url: patreonURL, error: .constant(nil))
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                workspace.open(patreonURL)
                            } label: {
                                Image(systemName: "arrow.up.forward")
                                    .padding(5)
                                    .foregroundStyle(.foreground)
                            }
                            .clipShape(.circle)
                            .foregroundStyle(.thinMaterial)
                            .padding()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .clipShape(.rect(cornerRadius: 10))
        }
        .padding()

        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Looking for help"
                presence.state = "Viewing Support"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"

                return presence
            }())
        }

        .navigationTitle("Support")
    }
}

#Preview {
    SupportView()
}
