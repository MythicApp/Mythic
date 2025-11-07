//
//  Workspace.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 20/5/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit
import SwiftUI

extension NSWorkspace {
    var systemArchitecture: String? {
        var sysinfo = utsname()
        uname(&sysinfo)

        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        }
    }

    var isARM: Bool {
        let arch = systemArchitecture ?? .init()
        return arch.contains("arm64")
    }

    struct UnsupportedArchitectureError: LocalizedError {
        var errorDescription: String? = """
            Your device uses an Intel® processor.
            This feature isn’t available on Intel®-based macs.
            """
    }
}
