//
//  BundleIconView.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import SwiftUI

public struct BundleIconView: View {
    private var appIconName: String? {
        guard let icon = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String else { return nil }

        return icon
    }

    public var body: some View {
        if let appIconName = appIconName,
            let icon = NSImage(named: appIconName) {
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
