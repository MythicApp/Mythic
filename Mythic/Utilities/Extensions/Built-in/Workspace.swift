//
//  Workspace.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 20/5/2024.
//

import Foundation
import AppKit

extension NSWorkspace {
    func isARM() -> Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        guard let machineString = machine else {
            return false
        }
        
        return machineString.starts(with: "arm64")
    }
}
