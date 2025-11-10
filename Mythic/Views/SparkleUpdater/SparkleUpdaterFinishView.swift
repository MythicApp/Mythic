//
//  SparkleUpdaterFinishView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

extension SparkleUpdater {
    struct FinishView: View {
        let dismiss: (Bool) -> Void

        var body: some View {
            RichAlertView(
                title: {
                    Text("Update Installed")
                },
                message: {
                    Text("The update has been installed successfully. Relaunch to apply the update.")
                },
                buttonsRight: {
                    HStack(spacing: 8) {
                        Button("Update on Close") {
                            dismiss(false)
                        }
                        
                        Button("Relaunch Now") {
                            dismiss(true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            )
        }
    }
}

#Preview {
    SparkleUpdater.FinishView(dismiss: { _ in })
}
