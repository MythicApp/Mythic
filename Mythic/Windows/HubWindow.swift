//
//  HubWindow.swift
//  Mythic
//

import SwiftUI

@preconcurrency public final class HubWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    public override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        super.init()
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        self.windowDidLoad()
    }
    
    deinit {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    /// When the window loads.
    private func windowDidLoad() {
        window?.center()
        window?.contentView = NSHostingView(rootView: HubView())
    }
    
    /// Show the window.
    public func show() {
        window?.makeKeyAndOrderFront(nil)
    }
    
    /// Hide the window.
    public func hide() {
        window?.close()
    }
}
