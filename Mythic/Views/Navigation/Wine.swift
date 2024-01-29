//
//  Wine.swift
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

struct WineView: View {
    var body: some View {
        NotImplementedView()
        if let bottles = Wine.allBottles {
            List {
                ForEach(Array(bottles.keys), id: \.self) { name in
                    Text("raaa \(name)")
                    Text("raaah \(bottles[name]!.url.prettyPath())")
                }
            }
            .padding()
        }
    }
}

#Preview {
    WineView()
}
