//
//  SparkleUpdaterExtractingView.swift
//  Mythic
//

import SwiftUI

public struct SparkleUpdaterExtractingView: View {
    public var progress: Double

    @State private var timeRemaining: Double?
    @State private var downloaded: Double = 0

    public var body: some View {
        // HStack(alignment: .top, spacing: 16) {
        //     BundleIconView()
        //         .frame(width: 64, height: 64)
        //     VStack(alignment: .leading, spacing: 8) {
        //         VStack(alignment: .leading, spacing: 4) {
        //             Text("sparkleUpdaterExtractingView.title")
        //                 .bold()
        //             Text("sparkleUpdaterExtractingView.description")
        //                 .foregroundStyle(.secondary)
        //         }
        //         ProgressView(value: progress, total: 100)
        //             .progressViewStyle(.linear)
        //     }
        //     .frame(maxWidth: .infinity, maxHeight: .infinity)
        // }
        // .padding(20)
        // .frame(width: 512)
        RichAlertView(
            title: {
                Text("sparkleUpdaterExtractingView.title")
            },
            message: {
                Text("sparkleUpdaterExtractingView.description")
            },
            content: {
                ProgressView(value: progress * 1000, total: 1000)
                    .progressViewStyle(.linear)
            }
        )
    }
}

#Preview {
    SparkleUpdaterExtractingView(progress: 0.5)
}
