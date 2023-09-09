//
//  Welcome.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/9/2023.
//

import SwiftUI

struct WelcomeView: View {
    @State private var appVersion = ""
    @State private var buildNumber = ""
    
    var body: some View {
        VStack {
            Text("App version: \(appVersion)")
            Text("Build number: \(buildNumber)")
        }
        .onAppear {
            if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                self.appVersion = appVersion
            } else {
                self.appVersion = "Version not available"
            }
            
            if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                self.buildNumber = buildNumber
            } else {
                self.buildNumber = "Build number not available"
            }
        }
    }
}

#Preview {
    WelcomeView()
}
