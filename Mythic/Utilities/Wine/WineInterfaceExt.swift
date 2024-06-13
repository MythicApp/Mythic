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
import OSLog

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
    struct UnableToBootError: LocalizedError {
        // TODO: proper implementation, see `Wine.boot(prefix: <#URL#>)`
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
    
    class Bottle: Codable, Hashable, Identifiable, Equatable {
        static func == (lhs: Bottle, rhs: Bottle) -> Bool {
            return (lhs.url == rhs.url && lhs.id == rhs.id)
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(id)
        }

        /// Initializes a new bottle, checking if a bottle at the given URL already exists and attempting to fetch its properties.
        init(name: String, url: URL, id: UUID = .init(), settings: BottleSettings) {
            let existingBottle = try? getBottleObject(url: url)
            if existingBottle != nil {
                log.notice("Bottle Initializer: Bottle already exists at \(url.prettyPath()); fetching known properties.")
                if existingBottle?.url != url {
                    log.debug("Bottle Initializer: Fetched URL doesn't match known URL; updating.")
                }
            } else if bottleExists(bottleURL: url) {
                log.warning("Bottle Initializer: Bottle already exists at \(url.prettyPath()), but unable to fetch known properties; overwriting")
            }
            
            self.name = existingBottle?.name ?? name
            self.url = url
            self.id = existingBottle?.id ?? id
            self.settings = existingBottle?.settings ?? settings
            self.propertiesFile = url.appendingPathComponent("properties.plist")
        }
        
        init?(knownURL: URL) {
            guard bottleExists(bottleURL: knownURL) else { log.warning("Bottle Initializer: Unable to intialize nonexistent bottle."); return nil }
            guard let object = try? getBottleObject(url: knownURL) else {
                log.error("Bottle Initializer: Unable to fetch object for existing bottle.")
                return nil
            }
            if object.url != knownURL {
                log.warning("Bottle Initializer: Fetched URL doesn't match known URL; updating.")
            }
            self.name = object.name
            self.url = knownURL
            self.id = object.id
            self.settings = object.settings
            self.propertiesFile = knownURL.appendingPathComponent("properties.plist")
        }

        /// Convenience initializer to create a bottle from a URL.
        convenience init(createFrom url: URL) {
            self.init(name: url.lastPathComponent, url: url, settings: defaultBottleSettings)
        }

        deinit { saveProperties() }

        /// Saves the bottle properties to disk.
        func saveProperties() {
            guard files.fileExists(atPath: url.path()) else { return }
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(self)
                try data.write(to: propertiesFile)
            } catch {
                Logger.app.error("Error encoding & writing to properties file for bottle \"\(self.name)\" (\(self.url.prettyPath()))")
            }
        }

        var name: String
        var url: URL
        var id: UUID
        var settings: BottleSettings

        private(set) var propertiesFile: URL
    }
    
    struct BottleSettings: Codable, Hashable {
        var metalHUD: Bool
        var msync: Bool
        var retinaMode: Bool
        var DXVK: Bool
        var DXVKAsync: Bool
        var windowsVersion: WindowsVersion
        var scaling: Double
    }
    
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
    
    struct UnableToQueryRegistryError: LocalizedError {
        var errorDescription: String? = "Unable to query registry of bottle."
    }
}
