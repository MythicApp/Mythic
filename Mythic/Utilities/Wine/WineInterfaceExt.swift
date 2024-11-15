//
//  WineInterfaceExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 30/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

extension Wine {
    /// A struct to hold closures for handling stdout and stderr output.
    struct OutputHandler {
        /// A closure to handle stdout output.
        let stdout: (String) -> Void

        /// A closure to handle stderr output.
        let stderr: (String) -> Void
    }

    /// Signifies that a container is unable to boot.
    struct UnableToBootError: LocalizedError {
        var errorDescription: String? = "Container unable to boot." // TODO: add reason if possible
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

    // TODO: refactor
    class Container: Codable, Hashable, Identifiable, Equatable, ObservableObject {
        static func == (lhs: Container, rhs: Container) -> Bool {
            return (lhs.url == rhs.url && lhs.id == rhs.id)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(id)
        }

        /// Initializes a new container, checking if a container at the given URL already exists and attempting to fetch its properties.
        init(name: String, url: URL, id: UUID = .init(), settings: ContainerSettings) {
            let existingContainer = try? getContainerObject(url: url)
            if existingContainer != nil {
                log.notice("Container Initializer: Container already exists at \(url.prettyPath()); fetching known properties.")
                if existingContainer?.url != url {
                    log.debug("Container Initializer: Fetched URL doesn't match known URL; updating.")
                }
            } else if containerExists(at: url) {
                log.warning("Container Initializer: Container already exists at \(url.prettyPath()), but unable to fetch known properties; overwriting")
            }

            self.name = existingContainer?.name ?? name
            self.url = url
            self.id = existingContainer?.id ?? id
            self.settings = existingContainer?.settings ?? settings
            self.propertiesFile = url.appendingPathComponent("properties.plist")

            saveProperties()
        }

        init?(knownURL: URL) {
            guard containerExists(at: knownURL) else { log.warning("Container Initializer: Unable to intialize nonexistent container."); return nil }
            guard let object = try? getContainerObject(url: knownURL) else {
                log.error("Container Initializer: Unable to fetch object for existing container.")
                return nil
            }

            self.name = object.name
            self.url = knownURL
            self.id = object.id
            self.settings = object.settings
            self.propertiesFile = knownURL.appendingPathComponent("properties.plist")

            if object.url != knownURL {
                log.warning("Container Initializer: Fetched URL doesn't match known URL; updating.")
                saveProperties()
            }
        }

        /// Convenience initializer to create a container from a URL.
        convenience init(createFrom url: URL) {
            self.init(name: url.lastPathComponent, url: url, settings: defaultContainerSettings)
        }

        // deinit { saveProperties() } // FIXME: causes conflict with didSet

        /// Saves the container properties to disk.
        func saveProperties() {
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(self)
                try data.write(to: propertiesFile)
            } catch {
                Logger.app.error("Error encoding & writing to properties file for container \"\(self.name)\" (\(self.url.prettyPath()))")
            }
        }

        var name: String { didSet { saveProperties() } } // MARK: futureproofing
        var url: URL
        var id: UUID
        var settings: ContainerSettings { didSet { saveProperties() } } // FIXME: just for certainty; mythic's still in alpha, remember?

        private(set) var propertiesFile: URL
    }

    struct ContainerSettings: Codable, Hashable {
        var metalHUD: Bool
        var msync: Bool
        var retinaMode: Bool
        var DXVK: Bool
        var DXVKAsync: Bool
        var windowsVersion: WindowsVersion
        var scaling: Int
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

    enum ContainerScope: String, CaseIterable {
        case individual
        case global
    }

    struct ContainerDoesNotExistError: LocalizedError {
        var errorDescription: String? = "Attempted to modify a container which doesn't exist."
    }

    struct ContainerAlreadyExistsError: LocalizedError {
        var errorDescription: String? = "Attempted to modify a container which already exists."
    }

    struct UnableToQueryRegistryError: LocalizedError {
        var errorDescription: String? = "Unable to query registry of container."
    }
}
