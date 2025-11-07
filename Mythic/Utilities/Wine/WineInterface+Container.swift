//
//  WineInterface+Container.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 30/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

extension Wine {
    final class Container: Identifiable, ObservableObject { // FIXME: final.. for now
        private static let log: Logger = .custom(category: "Wine.Container")

        /// Saves the container properties to disk.
        func saveProperties() {
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(self)
                try data.write(to: propertiesFile)
            } catch {
                Wine.Container.log.error("Error writing properties for container \"\(self.name)\" (\(self.url.prettyPath))")
            }
        }

        /// Initialise a new container, checking if a container at the given URL already exists.
        init(name: String, url: URL, id: UUID = .init(), settings: Container.Settings) {
            let existingContainer = try? Container(knownURL: url)

            self.name = existingContainer?.name ?? name
            self.url = url
            self.id = existingContainer?.id ?? id
            self.settings = existingContainer?.settings ?? settings

            saveProperties()
        }

        /// Initialise a container from an existing URL
        init(knownURL: URL) throws {
            guard containerExists(at: knownURL) else {
                Wine.Container.log.warning("Unable to initialise nonexistent container.")
                throw Container.DoesNotExistError()
            }

            let object = try getContainerObject(url: knownURL)

            self.name = object.name
            self.url = knownURL
            self.id = object.id
            self.settings = object.settings
        }

        /// Synthesize a container object from a URL.
        convenience init(createFrom url: URL) {
            self.init(name: url.lastPathComponent, url: url, settings: .init())
        }

        var name: String { didSet { saveProperties() } }
        var url: URL
        var id: UUID
        var settings: Container.Settings { didSet { saveProperties() } }

        var propertiesFile: URL { url.appending(path: "properties.plist") }
    }
}

extension Wine.Container: Equatable {
    static func == (lhs: Wine.Container, rhs: Wine.Container) -> Bool {
        return (lhs.url == rhs.url && lhs.id == rhs.id)
    }
}

extension Wine.Container: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(id)
    }
}

extension Wine.Container: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case id
        case settings
    }
}

extension Wine.Container {
    struct Process {
        var name: String = .init()
        var pid: Int = .init()
    }

    struct Settings: Codable, Hashable, Equatable {
        var metalHUD: Bool
        var msync: Bool
        var retinaMode: Bool
        var dxvk: Bool
        var dxvkAsync: Bool
        var windowsVersion: Wine.WindowsVersion
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

        init(metalHUD: Bool = false,
             msync: Bool = true,
             retinaMode: Bool = true,
             dxvk: Bool = false,
             dxvkAsync: Bool = false,
             windowsVersion: Wine.WindowsVersion = .win11,
             scaling: Int = 192,
             avx2: Bool = true) {
            self.metalHUD = metalHUD
            self.msync = msync
            self.retinaMode = retinaMode
            self.dxvk = dxvk
            self.dxvkAsync = dxvkAsync
            self.windowsVersion = windowsVersion
            self.scaling = scaling
            self.avx2 = {
                if #available(macOS 15.0, *) {
                    return avx2
                } else {
                    return false
                }
            }()
        }

        init(from decoder: Decoder) throws {
            self.init()
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.metalHUD = try container.decodeIfPresent(Bool.self, forKey: .metalHUD) ?? self.metalHUD
            self.msync = try container.decodeIfPresent(Bool.self, forKey: .msync) ?? self.msync
            self.retinaMode = try container.decodeIfPresent(Bool.self, forKey: .retinaMode) ?? self.retinaMode
            self.dxvk = try container.decodeIfPresent(Bool.self, forKey: .dxvk) ?? self.dxvk
            self.dxvkAsync = try container.decodeIfPresent(Bool.self, forKey: .dxvkAsync) ?? self.dxvkAsync
            self.windowsVersion = try container.decodeIfPresent(Wine.WindowsVersion.self, forKey: .windowsVersion) ?? self.windowsVersion
            self.scaling = try container.decodeIfPresent(Int.self, forKey: .scaling) ?? self.scaling
            self.avx2 = try container.decodeIfPresent(Bool.self, forKey: .avx2) ?? self.avx2
        }
    }

    enum Scope: String, CaseIterable {
        case individual
        case global
    }
}

extension Wine.Container {
    struct DoesNotExistError: LocalizedError {
        var errorDescription: String? = String(localized: """
            Attempted to access a container that doesn't exist.
            If relevant, please verify that the container is set correctly.
            """)
    }

    struct UnableToBootError: LocalizedError {
        var errorDescription: String? = String(localized: "Container unable to boot.") // TODO: add reason if possible
    }

    struct AlreadyExistsError: LocalizedError {
        var errorDescription: String? = String(localized: "Attempted to access a container that already exists.")
    }
}
