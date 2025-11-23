//
//  DownloadCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 26/6/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct DownloadCard: View {
    @Binding var game: Game

    @Bindable private var operationManager: GameOperationManager = .shared

    var body: some View {

    }
}

#Preview {
    DownloadCard(game: .constant(placeholderGame))
}
