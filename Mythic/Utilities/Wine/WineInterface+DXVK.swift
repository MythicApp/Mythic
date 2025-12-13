//
//  WineInterface+DXVK.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension Wine {
    final class DXVK {
        /// Replaces the Engine’s DirectX DLLs in the specified Wine container with their DXVK equivalents.
        static func install(toContainerAtURL containerURL: URL) async throws {
            try Wine.killAll(at: containerURL)

            // x64
            try FileManager.default.removeItemIfExists(at: containerURL.appending(path: "drive_c/windows/system32/d3d10core.dll"))
            try FileManager.default.removeItemIfExists(at: containerURL.appending(path: "drive_c/windows/system32/d3d11.dll"))

            // x32
            try FileManager.default.removeItemIfExists(at: containerURL.appending(path: "drive_c/windows/syswow64/d3d10core.dll"))
            try FileManager.default.removeItemIfExists(at: containerURL.appending(path: "drive_c/windows/syswow64/d3d11.dll"))

            // x64
            try FileManager.default.forceCopyItem(
                at: Engine.directory.appending(path: "DXVK/x64/d3d10core.dll"),
                to: containerURL.appending(path: "drive_c/windows/system32")
            )
            try FileManager.default.forceCopyItem(
                at: Engine.directory.appending(path: "DXVK/x64/d3d11.dll"),
                to: containerURL.appending(path: "drive_c/windows/system32")
            )

            // x32
            try FileManager.default.forceCopyItem(
                at: Engine.directory.appending(path: "DXVK/x32/d3d10core.dll"),
                to: containerURL.appending(path: "drive_c/windows/syswow64")
            )
            try FileManager.default.forceCopyItem(
                at: Engine.directory.appending(path: "DXVK/x32/d3d11.dll"),
                to: containerURL.appending(path: "drive_c/windows/syswow64")
            )
        }

        // to remove DXVK, you must run wineboot in update mode
    }
}
