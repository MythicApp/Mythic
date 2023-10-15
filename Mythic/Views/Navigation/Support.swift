//
//  Support.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI

struct SupportView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .onAppear {
                print(isAppInstalled(bundleIdentifier: "com.isaacmarovitz.Whisky"))
                print(try! Legendary.isAlias(game: "amongus"))
            }
    }
}

#Preview {
    SupportView()
}
