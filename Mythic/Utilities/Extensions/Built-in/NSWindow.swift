//
//  NSWindow.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/24.
//

import AppKit

extension NSWindow {
    var isImmersive: Bool {
        get {
            return self.titlebarAndTextHidden &&
            self.isMovableByWindowBackground &&
            self.standardWindowButton(.miniaturizeButton)?.isHidden == true &&
            self.standardWindowButton(.zoomButton)?.isHidden == true
        }
        set {
            self.titlebarAndTextHidden = newValue
            self.isMovableByWindowBackground = newValue
            self.standardWindowButton(.miniaturizeButton)?.isHidden = newValue
            self.standardWindowButton(.zoomButton)?.isHidden = newValue
        }
    }

    var titlebarAndTextHidden: Bool {
        get {
            return self.titlebarAppearsTransparent == true &&
            self.titleVisibility == .visible
        }
        set {
            self.titlebarAppearsTransparent = newValue
            self.titleVisibility = newValue ? .hidden : .visible
        }
    }
}
