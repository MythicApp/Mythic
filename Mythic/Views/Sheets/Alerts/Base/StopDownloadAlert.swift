//
//  StopDownloadAlert.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/12/2023.
//

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
