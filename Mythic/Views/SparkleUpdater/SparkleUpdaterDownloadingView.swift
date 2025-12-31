//
//  SparkleUpdaterDownloadingView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import Combine

extension SparkleUpdater {
    struct DownloadingView: View {
        let cancel: () -> Void
        let downloadStartTimestamp: Date
        let bytesDownloaded: UInt64
        let bytesTotal: UInt64

        @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        @State private var timeRemaining: Double?
        @State private var downloaded: UInt64 = 0

        var body: some View {
            RichAlertView(
                title: {
                    Text("Downloading Update")
                },
                content: {
                    VStack(alignment: .leading, spacing: 2) {
                        if bytesTotal != 0 {
                            ProgressView(value: Double(bytesDownloaded), total: Double(bytesTotal))
                                .progressViewStyle(.linear)
                            
                            if let timeRemaining {
                                Text("""
                                    \(formatBytes(downloaded)) of \(formatBytes(bytesTotal)) downloaded.
                                    About \(formatTimeRemaining(timeRemaining)) remaining.
                                    """)
                                    .foregroundStyle(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                            } else {
                                Text("\(formatBytes(downloaded)) of \(formatBytes(bytesTotal)) downloaded.")
                                    .foregroundStyle(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                            
                            Text("\(formatBytes(downloaded)) downloaded.")
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                },
                buttonsRight: {
                    Button("Cancel") {
                        cancel()
                    }
                }
            )
            .onReceive(timer) { _ in
                withAnimation {
                    downloaded = bytesDownloaded
                    
                    let timeElapsed: TimeInterval = .init() - downloadStartTimestamp.timeIntervalSinceReferenceDate
                    
                    if timeElapsed > 6 && bytesDownloaded > 0 {
                        let bytesRemaining: Double = .init(bytesTotal - bytesDownloaded)
                        let bytesPerSecond: Double = .init(bytesDownloaded) / timeElapsed
                        timeRemaining = bytesRemaining / bytesPerSecond
                    } else {
                        timeRemaining = nil
                    }
                }
            }
        }

        private func formatTimeRemaining(_ time: Double) -> String {
            let formatter: DateComponentsFormatter = .init()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = [.hour, .minute, .second]
            return formatter.string(from: time) ?? ""
        }

        private func formatBytes(_ bytes: UInt64) -> String {
            let formatter: ByteCountFormatter = .init()
            formatter.countStyle = .file
            formatter.zeroPadsFractionDigits = true
            return formatter.string(fromByteCount: Int64(bytes))
        }
    }
}

#Preview {
    SparkleUpdater.DownloadingView(
        cancel: {},
        downloadStartTimestamp: .init(),
        bytesDownloaded: 0,
        bytesTotal: 0
    )
}
