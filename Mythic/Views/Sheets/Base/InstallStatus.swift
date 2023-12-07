//
//  InstallStatus.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 3/12/2023.
//

import SwiftUI
import Foundation
import Charts // TBA

struct InstallStatusView: View {
    private let status: Legendary.InstallStatus = Legendary.Installing.installStatus
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Text("Downloading \(Legendary.Installing.game?.title ?? "[unknown]")…")
                .font(.title)
            
            GroupBox {
                Text("Progress: \(Int(status.progress?.percentage ?? 0))% (\(status.progress?.downloaded ?? 0)/\(status.progress?.total ?? 0) objects)")
                Text("Downloaded \(status.download?.downloaded ?? 0) MiB, Written \(status.download?.written ?? 0)")
                Text("Elapsed: \("\(status.progress?.runtime ?? "[unknown]")"), ETA: \("\(status.progress?.eta ?? "[unknown]")")")
            }
            .fixedSize()
            
            Button("Close") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.accent)
        }
        .padding()
    }
}

#Preview {
    InstallStatusView(isPresented: .constant(true))
}
