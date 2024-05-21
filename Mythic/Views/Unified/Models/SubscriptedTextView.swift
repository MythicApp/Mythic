//
//  SubscriptedTextView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 20/3/2024.
//

import SwiftUI

struct SubscriptedTextView: View {
    init(_ text: String) {
        self.text = text
    }
    
    var text: String = .init()
    
    var body: some View {
        Text(text)
            .font(.caption)
            // .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .overlay( // based off .buttonStyle(.accessoryBarAction)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.tertiary)
            )
    }
}

#Preview {
    SubscriptedTextView("Test Text")
        .padding()
}
