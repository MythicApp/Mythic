//
//  StopDownloadAlert.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/12/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI

func stopDownloadAlert(isPresented: Binding<Bool>, game: Legendary.Game?) -> Alert {
    return Alert(
        title: Text("Are you sure you want to stop downloading \(game?.title ?? "your game")?"),
        primaryButton: .destructive(Text("Stop")) {
            Legendary.stopCommand(identifier: "finalInstall")
            Legendary.Installing.shared.reset()
        },
        secondaryButton: .default(Text("Cancel")) { isPresented.wrappedValue = false }
    )
}
