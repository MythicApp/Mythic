//
//  Library.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI
import SwiftyJSON

struct LibraryView: View {
    
    @State private var addGameModalPresented = false
    @State private var legendaryStatus: JSON = JSON()
    
    @State private var isGameListRefreshCalled: Bool = false
    
    var body: some View {
        
        GameListView(isRefreshCalled: $isGameListRefreshCalled)
        
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        addGameModalPresented = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        
            .sheet(isPresented: $addGameModalPresented) {
                LibraryView.ImportGameView(
                    isPresented: $addGameModalPresented,
                    isGameListRefreshCalled: $isGameListRefreshCalled
                )
                    .fixedSize()
            }
        
            .onAppear {
                DispatchQueue.global(qos: .userInteractive).async {
                    let status = try! JSON(
                        data: Legendary.command(args: ["status","--json"], useCache: true).stdout
                    )
                    DispatchQueue.main.async {
                        legendaryStatus = status
                    }
                }
            }
        
        //Text("Games available: \(String(describing: legendaryStatus["games_available"])), Games installed: \(String(describing: legendaryStatus["games_installed"]))")
    }
}

#Preview {
    LibraryView()
}
