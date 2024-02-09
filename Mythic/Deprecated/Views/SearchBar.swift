//
//  SearchBar.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/1/2024.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        ZStack {
            TextField("Search", text: $text)
            
            HStack {
                Spacer()
                
                Button(action: {
                    text = .init()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                })
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .offset(x: -5)
                .opacity(text.isEmpty ? 0 : 1)
            }
        }
        .padding()
    }
}

#Preview {
    SearchBar(text: .constant(""))
}
