//
//  SparkleUpdaterExtractingView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI

extension SparkleUpdater {
    struct ExtractingView: View {
        let progress: Double

        var body: some View {
            RichAlertView(
                title: {
                    Text("Extracting Update")
                },
                message: {
                    Text("This may take a while.")
                },
                content: {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
            )
        }
    }
}

#Preview {
    SparkleUpdater.ExtractingView(progress: 0.5)
}
