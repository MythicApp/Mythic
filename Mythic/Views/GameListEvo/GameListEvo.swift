//
//  GameListEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 6/3/2024.
//

import SwiftUI

struct GameListEvo: View {
    @State private var searchString: String = .init()
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(
                    Array((try? Legendary.getInstallable()) ?? .init()).filter {
                        searchString.isEmpty || $0.title.localizedCaseInsensitiveContains(searchString)
                    }
                        .sorted { $0.title < $1.title }
                        .sorted { $0.isFavourited && !$1.isFavourited },
                    id: \.appName
                ) { game in
                    GameCard(game: .constant(game))
                        .padding()
                }
            }
            .searchable(text: $searchString, placement: .toolbar)
        }
    }
}

#Preview {
    GameListEvo()
}
