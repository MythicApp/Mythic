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
    
    var body: some View {
        HStack {
            VStack {
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .clipShape(.rect(cornerRadius: 10))
            .shimmering(
                animation: .easeInOut(duration: 1)
                    .repeatForever(autoreverses: false),
                bandSize: 1
            )
            
            VStack {
                VStack {
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .clipShape(.rect(cornerRadius: 10))
                .shimmering(
                    animation: .easeInOut(duration: 1)
                        .repeatForever(autoreverses: false),
                    bandSize: 1
                )
                
                VStack {
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .clipShape(.rect(cornerRadius: 10))
                .shimmering(
                    animation: .easeInOut(duration: 1)
                        .repeatForever(autoreverses: false),
                    bandSize: 1
                )
            }
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

struct ContentView: View {
    @State private var game: Game = .init(type: .local, title: "")

    var body: some View {
        VStack {
            Text("Current Title: \(game.title)")
                .padding()
            
            TextField("", text: $game.title)
            
            Button("Update Title") {
                game.title = "example"
            }
            
            Text("current id: \(game.id)")
            Button("Update id") {
                game.id = "example"
            }
            
            Text("current imageurl: \(String(describing: game.imageURL?.absoluteString))")
            Button("Update id") {
                game.imageURL = .init(string: "https://cdn.discordapp.com/attachments/924251802231259166/989319195881767013/image0.jpg?ex=6604b34c&is=65f23e4c&hm=106194fd2f28443c05136ddfa5a8a5591ac379c3ca87438d141535796ff6ddf2&")
            }
            
            Text("current platform: \(game.platform?.rawValue ?? "")")
            Button("Update id") {
                game.platform = .macOS
            }
        }
    }
}


#Preview {
    ContentView()
}
