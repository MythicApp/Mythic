//
//  SparkleUpdaterFinishView.swift
//  Mythic
//

import SwiftUI

public struct SparkleUpdaterFinishView: View {
    public let dismiss: (Bool) -> Void

    public var body: some View {
        // HStack(alignment: .top, spacing: 16) {
        //     BundleIconView()
        //         .frame(width: 64, height: 64)
        //     VStack(alignment: .leading, spacing: 8) {
        //         VStack(alignment: .leading, spacing: 4) {
        //             Text("sparkleUpdaterFinishView.title")
        //                 .bold()
        //             Text("sparkleUpdaterFinishView.description")
        //                 .foregroundStyle(.secondary)
        //         }
        //         HStack(spacing: 8) {
        //             Spacer()
        //             Button("sparkleUpdaterFinishView.updateOnClose") {
        //                 dismiss(false)
        //             }
        //             Button("sparkleUpdaterFinishView.relaunchNow") {
        //                 dismiss(true)
        //             }
        //             .buttonStyle(.borderedProminent)
        //         }
        //     }
        //     .frame(maxWidth: .infinity, maxHeight: .infinity)
        // }
        // .padding(20)
        // .frame(width: 512)
        RichAlertView(
            title: {
                Text("sparkleUpdaterFinishView.title")
            },
            message: {
                Text("sparkleUpdaterFinishView.description")
            },
            buttonsRight: {
                HStack(spacing: 8) {
                    Button("sparkleUpdaterFinishView.updateOnClose") {
                        dismiss(false)
                    }
                    Button("sparkleUpdaterFinishView.relaunchNow") {
                        dismiss(true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        )
    }
}

#Preview {
    SparkleUpdaterFinishView(dismiss: { _ in })
}
