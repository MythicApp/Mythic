//
//  OnboardingView.swift
//  Mythic
//

import SwiftUI

public struct OnboardingView: View {
    public var body: some View {
        OnboardingR2()
            .contentTransition(.opacity)
            .frame(minWidth: 800, minHeight: 400)
            .environmentObject(NetworkMonitor.shared)
            .environmentObject(SparkleController())
    }
}


#Preview {
    OnboardingView()
}
