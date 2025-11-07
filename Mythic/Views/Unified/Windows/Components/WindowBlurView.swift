//
//  WindowBlurView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 9/29/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

/**
 Modifier that blurs a view's enclosing window.
 
 Example Usage:
    SwiftUI: `.background(WindowBlurView().ignoresSafeArea())`
 */
struct WindowBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}
