//
//  NSApplication.swift
//  Mythic
//
//  Created by zenfty on 11/10/24.
//

// Copyright © 2023-2026 zenfty

import AppKit

extension NSApplication {
    func window(withID id: String) -> NSWindow? {
        return windows.first { $0.identifier?.rawValue == id }
    }
}
