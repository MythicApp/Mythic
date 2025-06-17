//
//  SparkleUpdaterCheckingView.swift
//  Mythic
//

import SwiftUI

public struct SparkleUpdaterCheckingView: View {
    public let cancel: () -> Void

    public var body: some View {
        RichAlertView(
            title: {
                Text("sparkleUpdaterCheckingView.title")
            },
            message: {
                Text("sparkleUpdaterCheckingView.description")
            },
            content: {
                ProgressView()
                    .progressViewStyle(.linear)
            },
            buttonsRight: {
                Button("common.cancel") {
                    cancel()
                }
            }
        )
    }
}

#Preview {
    SparkleUpdaterCheckingView(cancel: {})
}
