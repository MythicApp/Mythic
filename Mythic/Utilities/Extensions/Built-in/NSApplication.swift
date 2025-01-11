//
//  NSApplication.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/10/24.
//

import AppKit

extension NSApplication {
    func window(withID id: String) -> NSWindow? {
        return windows.first { $0.identifier?.rawValue == id }
    }
}
