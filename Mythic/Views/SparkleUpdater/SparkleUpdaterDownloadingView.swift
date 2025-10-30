//
//  SparkleUpdaterDownloadingView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

public struct SparkleUpdaterDownloadingView: View {
    public let cancel: () -> Void
    public let downloadStartTimestamp: Date
    public var bytesDownloaded: UInt64
    public var bytesTotal: UInt64

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: Double?
    @State private var downloaded: UInt64 = 0

    public init(cancel: @escaping () -> Void, downloadStartTimestamp: Date, bytesDownloaded: UInt64, bytesTotal: UInt64) {
        self.cancel = cancel
        self.downloadStartTimestamp = downloadStartTimestamp
        self.bytesDownloaded = bytesDownloaded
        self.bytesTotal = bytesTotal
    }

    public var body: some View {
        RichAlertView(
            title: {
                Text("Downloading Update")
            },
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    if bytesTotal != 0 {
                        ProgressView(value: Double(bytesDownloaded), total: Double(bytesTotal))
                            .progressViewStyle(.linear)
                        if let timeRemaining = timeRemaining {
                            Text(String(format: String(localized: "%@ of %@ downloaded, about %@ remaining."),
                                        formatBytes(downloaded),
                                        formatBytes(bytesTotal),
                                        formatTimeRemaining(timeRemaining)))
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                        } else {
                            Text(String(format: String(localized: "%@ of %@ downloaded."),
                                        formatBytes(downloaded),
                                        formatBytes(bytesTotal)))
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                        Text(String(format: String(localized: "%@ downloaded."),
                                    formatBytes(downloaded)))
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
                
                let timeElapsed = Date().timeIntervalSince(downloadStartTimestamp)
                
                // This could be more accurate if we used a window, but this is good enough
                if timeElapsed > 6 && bytesDownloaded > 0 {
                    let bytesRemaining = Double(bytesTotal - bytesDownloaded)
                    let bytesPerSecond = Double(bytesDownloaded) / timeElapsed
                    timeRemaining = bytesRemaining / bytesPerSecond
                } else {
                    timeRemaining = nil
                }
            }
        }
    }

    private func formatTimeRemaining(_ time: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: time) ?? ""
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    SparkleUpdaterDownloadingView(cancel: {}, downloadStartTimestamp: Date(), bytesDownloaded: 0, bytesTotal: 0)
}
