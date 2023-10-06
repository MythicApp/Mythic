//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI
import Cocoa

struct HomeView: View {
    var body: some View {
        Text("Hey,\n\(Legendary.whoAmI())!")
            .font(.title)
    }
}

#Preview {
    HomeView()
}
