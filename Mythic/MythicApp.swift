//
//  MythicApp.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/9/2023.
//

import SwiftUI
import OSLog

@main
struct MythicApp: App {
    
    init() {
        DispatchQueue.global().async {
            
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 750, minHeight: 390)
        }
    }
}
