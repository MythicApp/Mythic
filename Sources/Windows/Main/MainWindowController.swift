//
//  MainWindowController.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/23/24.
//

import Foundation
import SwiftUI

/// Controller for the main window
public class MainWindowController: NSWindowController, NSWindowDelegate {
    override public var windowNibName: NSNib.Name? { "MainWindow" }

    override public func windowDidLoad() {
        guard let window = window else { return }
        window.center()
        window.isMovableByWindowBackground = true
        // window.contentView = NSHostingView(rootView: MainView())
    }

    public func show() {
        window?.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        window?.close()
    }

    @IBAction func close(_ sender: Any) {
        self.window?.performClose(sender)
    }

    @IBAction func closeWindow(_ sender: Any) {
        self.window?.performClose(sender)
    }

    @IBAction func minimizeWindow(_ sender: Any) {
        self.window?.miniaturize(sender)
    }
}
