//
//  Workspace.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 20/5/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit

extension NSWorkspace {
    var isARM: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        }
        
        guard let machineString = machine else {
            return false
        }

        return machineString.contains("arm64")
    }
}
