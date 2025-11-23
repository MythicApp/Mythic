//
//  InstallStatus.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 3/12/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Foundation
import Charts // TODO: TODO

struct InstallStatusView: View {
    @Binding var isPresented: Bool
    @Bindable private var operationManager: GameOperationManager = .shared

    var body: some View {
        if let currentOperation = operationManager.queue.first {
            // TODO: reimplement to look better
        } else {
            ContentUnavailableView(
                "No download is currently in progress.",
                systemImage: "externaldrive.badge.checkmark"
            )
        }
        
        HStack {
            /*
             GameInstallProgressView.OperationProgressView(operation: operation,
                                                           showInitializer: false)
             */

            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding([.horizontal, .bottom])
        .frame(maxWidth: 750)
    }
}

#Preview {
    InstallStatusView(isPresented: .constant(true))
}
