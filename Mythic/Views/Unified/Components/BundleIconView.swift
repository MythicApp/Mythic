//
//  BundleIconView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI

public struct BundleIconView: View {
    private let bundleIconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String

    public var body: some View {
        if let bundleIconName,
            let icon = NSImage(named: bundleIconName) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    BundleIconView()
}
