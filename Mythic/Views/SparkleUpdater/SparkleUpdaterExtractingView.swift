//
//  SparkleUpdaterExtractingView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import SwiftUI

public struct SparkleUpdaterExtractingView: View {
    public var progress: Double

    @State private var timeRemaining: Double?
    @State private var downloaded: Double = 0

    public var body: some View {
        RichAlertView(
            title: {
                Text("Extracting Update")
            },
            message: {
                Text("This may take a while.")
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
