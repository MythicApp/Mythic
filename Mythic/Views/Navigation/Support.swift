//
//  Support.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Shimmer
import SwordRPC

struct SupportView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var colorSchemeValue: String {
        colorScheme == .dark ? "dark" : "light"
    }
    
    var body: some View {
        HStack {
            VStack {
                WebView(
                    url: .init(string: "https://discord.com/widget?id=1154998702650425397&theme=\(colorSchemeValue)")!,
                    error: .constant(nil),
                    isLoading: .constant(nil)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .clipShape(.rect(cornerRadius: 10))
            
            VStack {
                if let patreonURL: URL = .init(string: /* temp comment "https://patreon.com/mythicapp" */ "https://ko-fi.com/blackxfiied") {
                    WebView(url: patreonURL, error: .constant(nil), isLoading: .constant(nil))
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                workspace.open(patreonURL)
                            } label: {
                                Image(systemName: "arrow.up.forward")
                                    .padding(5)
                            }
                            .clipShape(.circle)
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
