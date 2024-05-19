//
//  Support.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Shimmer
import SwordRPC

struct SupportView: View {
    // TODO: https://arc.net/l/quote/icczlrwf
    @State private var game: Game = .init(type: .local, title: "default title")
    @ObservedObject var operation: GameOperation = .shared
    @State private var optionalPacks: [String: String] = .init()
    
    @State private var discordWidgetIsLoading: Bool = false
    var body: some View {
        HStack {
            VStack {
                WebView(
                    loadingError: Binding(get: {false}, set: {_ in}), // FIXME: terrible placeholders, webview refactor soon
                    canGoBack: Binding(get: {false}, set: {_ in}),
                    canGoForward: Binding(get: {false}, set: {_ in}),
                    isLoading: $discordWidgetIsLoading,
                    urlString: "https://discord.com/widget?id=1154998702650425397&theme=dark"
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .clipShape(.rect(cornerRadius: 10))
            
            VStack {
                WebView(
                    loadingError: Binding(get: {false}, set: {_ in}),
                    canGoBack: Binding(get: {false}, set: {_ in}),
                    canGoForward: Binding(get: {false}, set: {_ in}),
                    isLoading: $discordWidgetIsLoading,
                    urlString: "https://patreon.com/mythicapp"
                )
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        workspace.open(.init(string: "https://patreon.com/mythicapp")!)
                    } label: {
                        Image(systemName: "arrow.up.forward")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .padding()
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
