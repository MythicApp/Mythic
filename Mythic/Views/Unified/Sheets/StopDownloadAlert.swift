//
//  StopGameModificationAlert.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

// MARK: - StopDownloadAlert Function
/**
 Creates an alert for stopping the download.
 
 - Parameters:
    - isPresented: Binding to control the presentation of the alert.
    - game: The game for which the download is stopped.
 - Returns: An `Alert` instance.
 */
func stopGameOperationAlert(isPresented: Binding<Bool>, game: Game?) -> Alert { // rename to stopGameOperationAlert
    return Alert(
        title: Text("Are you sure you want to stop \(GameOperation.shared.current?.type.rawValue ?? "modifying") \(game?.title ?? "this game")?"),
        primaryButton: .destructive(Text("Stop")) {
            Legendary.stopCommand(identifier: "install")
        },
        secondaryButton: .default(Text("Cancel")) { isPresented.wrappedValue = false }
    )
}
