//
//  AboutView.swift
//  Mythic
//

import SwiftUI

public struct AboutView: View {
    public var body: some View {
        AboutWindowView()
            .contentTransition(.opacity)
            .frame(width: 285, height: 400)
            .environmentObject(NetworkMonitor.shared)
            .environmentObject(SparkleController())
    }
}


#Preview {
    OnboardingView()
}
