//
//  SparkleUpdaterInstallingView.swift
//  Mythic
//

import SwiftUI

public struct SparkleUpdaterInstallingView: View {
    public var body: some View {
        // HStack(alignment: .top, spacing: 16) {
        //     BundleIconView()
        //         .frame(width: 64, height: 64)
        //     VStack(alignment: .leading, spacing: 8) {
        //         VStack(alignment: .leading, spacing: 4) {
        //             Text("sparkleUpdaterInstallingView.title")
        //                 .bold()
        //             Text("sparkleUpdaterInstallingView.description")
        //                 .foregroundStyle(.secondary)
        //         }
        //         ProgressView()
        //             .progressViewStyle(.linear)
        //     }
        //     .frame(maxWidth: .infinity, maxHeight: .infinity)
        // }
        // .padding(20)
        // .frame(width: 512)
        RichAlertView(
            title: {
                Text("sparkleUpdaterInstallingView.title")
            },
            message: {
                Text("sparkleUpdaterInstallingView.description")
            },
            content: {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        )
    }
}

#Preview {
    SparkleUpdaterInstallingView()
}
