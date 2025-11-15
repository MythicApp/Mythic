//
//  StopGameModificationAlert.swift
//  Mythic
//
// Copyright © 2023-2025 vapidinfinity

import SwiftUI

/**
 Creates an alert for stopping the download.
 
 - Parameters:
    - isPresented: Binding to control the presentation of the alert.
    - game: The game for which the download is stopped.
 - Returns: An `Alert` instance.
 */
func stopGameOperationAlert(isPresented: Binding<Bool>, game: LegacyGame?) -> Alert {
    return Alert(
        title: Text("Are you sure you want to stop \(GameOperation.shared.current?.type.rawValue ?? "modifying") \(game?.title ?? "this game")?"),
        primaryButton: .destructive(Text("Stop")) {
            Task { @MainActor in
                await Legendary.RunningCommands.shared.stop(id: "install")
            }
        },
        secondaryButton: .default(Text("Cancel")) { isPresented.wrappedValue = false }
    )
}
