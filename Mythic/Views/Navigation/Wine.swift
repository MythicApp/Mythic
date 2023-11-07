//
//  Wine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI

struct WineView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        /*
        if isAppInstalled(bundleIdentifier: "com.isaacmarovitz.Whisky") {
            Circle()
                .foregroundColor(.green)
                .frame(width: 10, height: 10)
                .shadow(color: .green, radius: 10, x: 1, y: 1)
            Text("Whisky installed!")
                .onAppear {
                    print("get bottles: \(WhiskyInterface.getBottles())")
                    print("get bottle paths: \(WhiskyInterface.getBottlePaths()?.description ?? "none")")
                    print("get bottle meta: \(String(describing: WhiskyInterface.getBottleMetadata(bottleURL: URL(filePath: "Users/blackxfiied/Library/Containers/com.isaacmarovitz.Whisky/Bottles/C3A79656-22E2-41FE-A532-E43CDA2146C7"))))")
                }
        } else {
            Circle()
                .foregroundColor(.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red, radius: 10, x: 1, y: 1)
            Text("Whisky is not installed!")
        }
         */
    }
}

#Preview {
    WineView()
}
