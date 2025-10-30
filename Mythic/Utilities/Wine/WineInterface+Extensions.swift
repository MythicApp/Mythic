//
//  WineInterface+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 30/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

extension Wine {
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
            self.init(name: url.lastPathComponent, url: url, settings: .init())
        }

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

        // swiftlint:disable:next nesting
        struct Process {
            var name: String = .init()
            var pid: Int = .init()
        }
    }

    struct ContainerSettings: Codable, Hashable, Equatable {
        var metalHUD: Bool
        var msync: Bool
        var retinaMode: Bool
        var dxvk: Bool
        var dxvkAsync: Bool
        var windowsVersion: WindowsVersion
        var scaling: Int
        var avx2: Bool

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case metalHUD
            case msync
            case retinaMode
            case dxvk
            case dxvkAsync
            case windowsVersion
            case scaling
            case avx2
        }

        init(
            metalHUD: Bool = false,
            msync: Bool = true,
            retinaMode: Bool = true,
            dxvk: Bool = false,
            dxvkAsync: Bool = false,
            windowsVersion: WindowsVersion = .win11,
            scaling: Int = 192,
            avx2: Bool = {
                if #available(macOS 15.0, *) {
                    return true
                } else {
                    return false
                }
            }()
        ) {
            self.metalHUD = metalHUD
            self.msync = msync
            self.retinaMode = retinaMode
            self.dxvk = dxvk
            self.dxvkAsync = dxvkAsync
            self.windowsVersion = windowsVersion
            self.scaling = scaling
            self.avx2 = avx2
        }

        init(from decoder: Decoder) throws {
            self.init()
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.metalHUD = try container.decodeIfPresent(Bool.self, forKey: .metalHUD) ?? self.metalHUD
            self.msync = try container.decodeIfPresent(Bool.self, forKey: .msync) ?? self.msync
            self.retinaMode = try container.decodeIfPresent(Bool.self, forKey: .retinaMode) ?? self.retinaMode
            self.dxvk = try container.decodeIfPresent(Bool.self, forKey: .dxvk) ?? self.dxvk
            self.dxvkAsync = try container.decodeIfPresent(Bool.self, forKey: .dxvkAsync) ?? self.dxvkAsync
            self.windowsVersion = try container.decodeIfPresent(WindowsVersion.self, forKey: .windowsVersion) ?? self.windowsVersion
            self.scaling = try container.decodeIfPresent(Int.self, forKey: .scaling) ?? self.scaling
            self.avx2 = try container.decodeIfPresent(Bool.self, forKey: .avx2) ?? self.avx2
        }
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
        var errorDescription: String? = """
        Attempted to access a container that doesn't exist.
        If relevant, please verify that the container is set correctly.
        """
    }

    struct ContainerAlreadyExistsError: LocalizedError {
        var errorDescription: String? = "Attempted to access a container that already exists."
    }

    struct UnableToQueryRegistryError: LocalizedError {
        var errorDescription: String? = "Unable to query registry of container."
    }
}
