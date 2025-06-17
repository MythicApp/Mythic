//
//  SparkleUpdaterPreviewView.swift
//  Mythic
//

import SwiftUI
import Sparkle
import MarkdownUI

public struct SparkleUpdaterPreviewView: View {
    public let appcast: SUAppcastItem
    public let choice: (SparkleUpdateControllerModel.UpdateChoice) -> Void

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .center, spacing: 32) {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        BundleIconView()
                            .shadow(radius: 16)
                            .frame(width: 64, height: 64)
                        VStack(spacing: 2) {
                            Text(AppDelegate.applicationBundleName)
                                .font(.title2)
                                .bold()
                            Text(String(format: "v%@ (%@)",
                                        appcast.displayVersionString.isEmpty ? "0.0.0" : appcast.displayVersionString,
                                        appcast.versionString.isEmpty ? "0" : appcast.versionString))
                            .font(.caption)
                            .opacity(0.6)
                        }
                    }
                    
                    Text(String(format: String(localized: "sparkleUpdaterPreviewView.description"),
                                String(format: "v%@", AppDelegate.applicationVersion.description)))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .opacity(0.6)
                }

                VStack(spacing: 8) {
                    Button {
                        choice(.update)
                    } label: {
                        Text("sparkleUpdaterPreviewView.update")
                            .padding(6)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    if !appcast.isCriticalUpdate {
                        Button {
                            choice(.dismiss)
                        } label: {
                            Text("sparkleUpdaterPreviewView.dismiss")
                                .padding(6)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(24)
            .frame(width: 256, height: nil, alignment: .center)
            .frame(maxHeight: .infinity)
            .background(ColorfulBackgroundView())
            .foregroundStyle(.white)
            if let itemDescription = appcast.itemDescription, !itemDescription.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("sparkleUpdaterPreviewView.releaseNotes")
                            .bold()
                            .font(.title2)
                        Markdown {
                            itemDescription
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "pc")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                    Text("sparkleUpdaterPreviewView.noReleaseNotes")
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: 668, height: 384)
    }
}

#Preview {
    SparkleUpdaterPreviewView(appcast: .empty(), choice: { _ in })
}
