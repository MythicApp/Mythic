//
//  WineInterfaceExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 30/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

extension Wine {
    /// Enumeration containing the two terminal stream types.
    enum Stream {
        case stdout
        case stderr
    }
    
    /// A struct to hold closures for handling stdout and stderr output.
    struct OutputHandler {
        /// A closure to handle stdout output.
        let stdout: (String) -> Void

        /// A closure to handle stderr output.
        let stderr: (String) -> Void
    }
    
    /// Represents a condition to be checked for in the output streams before input is appended.
    struct InputIfCondition {
        /// The stream to be checked (stdout or stderr).
        let stream: Stream

        /// The string pattern to be matched in the selected stream's output.
        let string: String
    }
    
    /// Signifies that a wineprefix is unable to boot.
    struct BootError: LocalizedError {
        
        // TODO: proper implementation, see `Wine.boot(prefix: <#URL#>)`
        let reason: String? = nil
        var errorDescription: String? = "Bottle unable to boot." // TODO: add reason if possible
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
    
    struct Bottle: Codable, Hashable {
        var url: URL
        var settings: BottleSettings
        var busy: Bool
    }
    
    struct BottleSettings: Codable, Hashable {
        var metalHUD: Bool
        var msync: Bool
        var retinaMode: Bool // TODO: FIXME: turn into func
    }
    
    enum BottleScope: String, CaseIterable {
        case individual = "Individual"
        case global = "Global"
    }
    
    struct BottleDoesNotExistError: LocalizedError {
        var errorDescription: String? = "This bottle doesn't exist."
    }
    
    struct BottleAlreadyExistsError: LocalizedError {
        var errorDescription: String? = "This bottle already exists."
    }
    
    struct UnableToQueryRegistyError: LocalizedError {
        var errorDescription: String? = "Unable to query registry of bottle."
    }
}
