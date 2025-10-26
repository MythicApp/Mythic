//
//  SparkleUpdaterCheckingView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import SwiftUI

public struct SparkleUpdaterCheckingView: View {
    public let cancel: () -> Void

    public var body: some View {
        RichAlertView(
            title: {
                Text("Checking for Updates")
            },
            content: {
                ProgressView()
                    .progressViewStyle(.linear)
            },
            buttonsRight: {
                Button("Cancel") {
                    cancel()
                }
            }
        )
    }
}

#Preview {
    SparkleUpdaterCheckingView(cancel: {})
}
