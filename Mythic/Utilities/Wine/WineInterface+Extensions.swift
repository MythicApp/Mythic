//
//  WineInterface+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 7/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension Wine {
    enum WindowsVersion: String, Codable, CaseIterable {
        case win11 = "11"
        case win10 = "10"
        case win81 = "8.1"
        case win8 = "8"
        case win7 = "7"
        case vista = "Vista"
        case winxp = "XP"
        case win98 = "98"
    }

    internal enum RegistryType: String {
        case binary = "REG_BINARY"
        case dword = "REG_DWORD"
        case qword = "REG_QWORD"
        case string = "REG_SZ"
    }

    internal enum RegistryKey: String {
        case currentVersion = #"HKLM\Software\Microsoft\Windows NT\CurrentVersion"#
        case macDriver = #"HKCU\Software\Wine\Mac Driver"#
        case desktop = #"HKCU\Control Panel\Desktop"#
    }

    struct UnableToQueryRegistryError: LocalizedError {
        var errorDescription: String? = "Unable to query registry of container."
    }
}
