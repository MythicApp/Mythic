//
//  HubView.swift
//  Mythic
//

import SwiftUI

public struct HubView: View {
    public var body: some View {
        ContentView()
            .contentTransition(.opacity)
            .frame(minWidth: 800, minHeight: 400)
            .environmentObject(NetworkMonitor.shared)
            .environmentObject(SparkleController())
    }
}


#Preview {
    HubView()
}
