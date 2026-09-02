//
//  SubscriptedTextView.swift
//  Mythic
//
//  Created by zenfty on 20/3/2024.
//

// Copyright © 2023-2026 zenfty

import SwiftUI

struct SubscriptedTextView: View {
    init(_ text: String) {
        self.text = text
    }
    
    var text: String = .init()
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 5)
            .background( // based on .buttonStyle(.accessoryBarAction)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.tertiary)
            )
            .compositingGroup()
    }
}

#Preview {
    SubscriptedTextView("Test Text")
        .padding()
}
