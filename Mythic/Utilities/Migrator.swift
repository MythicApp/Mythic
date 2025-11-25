//
//  Migrator.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/4/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

// ‼️ This code should be removed before v1.0.0
// warning mediocre code lies ahead
// TODO: remove migration for v0.1.0 & v0.3.2
/// Migrate redundant data structures to newer data structures.
final class Migrator {
    private static let log: Logger = .custom(category: "Migrator")
    private static let containerQueue = DispatchQueue(label: "containerMigration")

    static func fullMigration() {
        v0_1_0.migrate()
        v0_3_2.migrate()
        v0_5_0.migrate()
    }

    struct v0_1_0 { // swiftlint:disable:this type_name
        private init() {}

        static func migrate() {
            Task(operation: { Migrator.v0_1_0.migrateFromAllBottlesFormat() })
        }

        /// Migrate redundant bottle format.
        /// Data migration from versions v0.1.1-alpha or earlier.
        static func migrateFromAllBottlesFormat() {
            // Determines eligibility by searching for redundant UserDefaults key "allBottles".
            guard let data = defaults.data(forKey: "allBottles"),
                  let decodedData = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]] else {
                return
            }

            containerQueue.sync {
                log.notice("Older bottle format detected, commencing bottle management system migration")

                var convertedBottles: [Wine.Container] = .init()

                for (index, (name, bottle)) in decodedData.enumerated() {
                    guard let urlArray = bottle["url"] as? [String: String], // unable to cast directly to URL, they're stored as arrays for whatever reason
                          let relativeURL = urlArray["relative"],
                          let url: URL = .init(string: relativeURL.removingPercentEncoding ?? relativeURL) else {
                        return
                    }

                    var settings: Wine.Container.Settings = .init()
                    guard let oldSettings = bottle["settings"] as? [String: Bool] else {
                        log.warning("Unable to read old bottle settings; using default")
                        continue
                    }

                    settings.metalHUD = oldSettings["metalHUD"] ?? settings.metalHUD
                    settings.msync = oldSettings["msync"] ?? settings.msync
                    settings.retinaMode = oldSettings["retinaMode"] ?? settings.retinaMode

                    convertedBottles.append(.init(name: name, url: url, settings: settings))
                    Wine.containerURLs.insert(url)

                    log.notice("converted \(url.prettyPath) (\(index + 1)/\(decodedData.count))")
                }

                log.notice("Bottle management system migration complete.")
                defaults.removeObject(forKey: "allBottles")
            }
        }
    }

    // MARK: - v0.3.2 or earlier
    /// Data migration from v0.3.2 or earlier
    struct v0_3_2 { // swiftlint:disable:this type_name
        private init() {}

        static func migrate() {
            Task(operation: { Migrator.v0_3_2.migrateBottleSchemeToContainerSchemeIfNecessary() })
            Task(operation: { await Migrator.v0_3_2.updateContainerScalingIfNecessary() })
            Task(operation: { Migrator.v0_3_2.migrateEpicFolderNaming() })
        }

        /// Migrate Bottle → Container naming scheme.
        /// Data migration from versions v0.3.2 and below.
        /// This must be ran **before** the "launchCount" UserDefaults key is appended to.
        static func migrateBottleSchemeToContainerSchemeIfNecessary() {
            guard let appContainer = Bundle.appContainer else { return }
            let oldScheme = appContainer.appending(path: "Bottles")
            let newScheme = appContainer.appending(path: "Containers")

            // determine eligibility by checking if old scheme exists at path
            guard files.fileExists(atPath: oldScheme.path) else { return }
            log.notice("Commencing bottle → container scheme migration.")

            containerQueue.sync {
                do {
                    try files.moveItem(at: oldScheme, to: newScheme)

                    if let contents = try? files.contentsOfDirectory(at: newScheme, includingPropertiesForKeys: nil) {
                        for containerURL in contents {
                            log.notice("Migrating container object: \(String(describing: try? Wine.Container(knownURL: containerURL)))")
                        }
                    }

                    // Migrate bottleURLs to containerURLs
                    if let bottleURLs = try? defaults.decodeAndGet([URL].self, forKey: "bottleURLs") {
                        let containerURLs = bottleURLs.map { bottleURL -> URL in
                            let currentPath = bottleURL.path(percentEncoded: false)
                            if currentPath.contains(oldScheme.path(percentEncoded: false)) {
                                let newPath = currentPath.replacingOccurrences(of: oldScheme.path(percentEncoded: false), with: newScheme.path(percentEncoded: false))
                                log.notice("Migrating bottle (modifying bottle URL from \(bottleURL) to \(newPath))...")
                                return URL(filePath: newPath)
                            } else {
                                return bottleURL
                            }
                        }

                        do {
                            try defaults.encodeAndSet(containerURLs, forKey: "containerURLs")
                            defaults.removeObject(forKey: "bottleURLs")
                        } catch {
                            log.error("Unable to re-encode default 'bottleURLs' as 'containerURLs': \(error.localizedDescription)")
                        }
                    }

                    // Game-specific bottleURL migration
                    defaults.dictionaryRepresentation() // FIXME: may update in the future with a PersistentGameData UD dictionary
                        .filter { $0.key.hasSuffix("_bottleURL") }
                        .forEach { key, value in
                            guard let currentURL = value as? URL else { return }
                            let currentPath = currentURL.path(percentEncoded: false)
                            guard files.fileExists(atPath: currentPath) else { return }

                            let filteredURL: URL
                            if currentPath.contains(oldScheme.path(percentEncoded: false)) {
                                let newPath = currentPath.replacingOccurrences(of: oldScheme.path(percentEncoded: false),
                                                                               with: newScheme.path(percentEncoded: false))
                                filteredURL = URL(filePath: newPath)
                            } else {
                                filteredURL = currentURL
                            }

                            let targetGameID = key.replacingOccurrences(of: "_bottleURL", with: "")
                            log.notice("Migrating game \(targetGameID)'s container URL...")
                            defaults.set(filteredURL, forKey: key.replacingOccurrences(of: "_bottleURL", with: "_containerURL"))
                            defaults.removeObject(forKey: key)
                        }

                    log.notice("Container renaming complete.")
                } catch {
                    log.error("Unable to rename Bottles to Containers: \(error.localizedDescription) -- Mythic may not function correctly.")
                }
            }
        }

        /// Updates containers without a default scale set.
        /// Data migration from versions v0.3.2 and below.
        static func updateContainerScalingIfNecessary() async {
            log.info("Migrating container scaling")
            // If scaling value is 0, it does not have a default scale set.
            for container in Wine.containerObjects where container.settings.scaling == 0 {
                let defaultScale = Wine.Container.Settings().scaling

                do {
                    try await Wine.setDisplayScaling(containerURL: container.url, dpi: defaultScale)
                    container.settings.scaling = defaultScale
                } catch {
                    log.error("Unable to migrate scaling for container at URL \(container.url.prettyPath): \(error)")
                }
            }
            log.info("Migrated container scaling.")
        }

        /// Rename Legendary configuration folder.
        /// Data migration from versions v0.3.2 and below.
        static func migrateEpicFolderNaming() {
            log.info("Migrating epic folder naming")
            let legendaryOldConfig: URL = Bundle.appHome!.appending(path: "Config")
            if files.fileExists(atPath: legendaryOldConfig.path) {
                try? files.moveItem(at: legendaryOldConfig, to: Legendary.configurationFolder)
            }
            log.info("Migrated epic folder naming.")
        }
    }

    // MARK: - v0.5.0 or earlier
    /// Data migration from v0.5.0 or earlier
    struct v0_5_0 { // swiftlint:disable:this type_name
        private init() {}

        static func migrate() {
            Task(operation: { await Migrator.v0_5_0.migrateFavouriteGames() })
            Task(operation: { await Migrator.v0_5_0.migrateLocalGamesLibrary() })
            Task(operation: { await Migrator.v0_5_0.migrateContainerURLs() })
            Task(operation: { await Migrator.v0_5_0.migrateLaunchArguments() })
            Task(operation: { await Migrator.v0_5_0.migrateImageURLs() })
            Task(operation: { await Migrator.v0_5_0.migrateWideImageURLs() })
        }

        // TODO: Migrate localGamesLibrary
        // recentlyPlayed will not be migrated.

        static func migrateFavouriteGames() async {
            try? await Game.store.refreshFromStorefronts()
            log.notice("Migrating favourite game storage.")

            if let oldFavouriteGames: [String] = defaults.stringArray(forKey: "favouriteGames") {
                await MainActor.run {
                    for id in oldFavouriteGames where Game.store.library.contains(where: { $0.id == id }) {
                        let targetGame = Game.store.library.first(where: { $0.id == id })!
                        targetGame.isFavourited = true
                    }
                }

                defaults.removeObject(forKey: "favouriteGames")
            }
        }

        static func migrateLocalGamesLibrary() async {
            try? await Game.store.refreshFromStorefronts()

            log.notice("Migrating local game library storage.")

            guard let data = defaults.data(forKey: "localGamesLibrary") else { return }
            guard let underlyingPlist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[[String: Any]]],
                  let properties = underlyingPlist.first else { return }

            for (index, item) in properties.enumerated() {
                guard let id = item["id"] as? String,
                      let title = item["title"] as? String,
                      let path = item["_path"] as? String,
                      let fetchedPlatform = item["_platform"] as? String,
                      let platform: Game.Platform = .allCases.first(where: { $0.description == fetchedPlatform }) else {
                    var itemDump: String = .init(); dump(item, to: &itemDump)
                    log.notice("""
                       Item found in local games library storage was malformed and could not be migrated.
                       Contents: \(itemDump)
                       """)
                    continue
                }

                let propertiesCount = properties.count
                await MainActor.run {
                    let game: LocalGame = .init(id: id,
                                                title: title,
                                                installationState: .installed(
                                                    location: .init(filePath: path),
                                                    platform: platform)
                    )

                    Game.store.library.insert(game)
                    log.notice("Successfully migrated local game \(game.title) from local games library storage. (\(index + 1)/\(propertiesCount))")
                }
            }

            defaults.removeObject(forKey: "localGamesLibrary")
        }

        static func migrateContainerURLs() async {
            try? await Game.store.refreshFromStorefronts()

            log.notice("Migrating game container URL storage.")

            for (key, url) in defaults.dictionaryRepresentation() where key.hasSuffix("_containerURL") {
                guard let url = url as? URL else { continue }
                let targetGameID: String = key.replacingOccurrences(of: "_containerURL", with: "")

                // check not for existence, but if it's in containerURLs
                // otherwise, it's a dead reference.
                guard Wine.containerURLs.contains(url) else {
                    log.warning("Container URL for game \(targetGameID) no longer exists. Skipping.")
                    continue
                }

                await MainActor.run {
                    guard let targetGame = Game.store.library.first(where: { $0.id == targetGameID }) else {
                        log.warning("Game with ID \(targetGameID) not found in store, skipping migration.")
                        return
                    }

                    targetGame.containerURL = url
                }

                defaults.removeObject(forKey: key)
            }
        }

        static func migrateLaunchArguments() async {
            try? await Game.store.refreshFromStorefronts()

            log.notice("Migrating game launch argument storage.")

            for (key, arguments) in defaults.dictionaryRepresentation() where key.hasSuffix("_launchArguments") {
                guard let arguments = arguments as? [String] else { continue }

                let targetGameID: String = key.replacingOccurrences(of: "_launchArguments", with: "")
                await MainActor.run {
                    guard let targetGame = Game.store.library.first(where: { $0.id == targetGameID }) else {
                        log.warning("Game with ID \(targetGameID) not found in store, skipping migration.")
                        return
                    }
                    if targetGame.launchArguments.isEmpty {
                        targetGame.launchArguments = arguments
                    } else {
                        log.warning("Game \(targetGame) already has launch arguments set, skipping migration.")
                    }
                }

                defaults.removeObject(forKey: key)
            }
        }

        static func migrateImageURLs() async {
            try? await Game.store.refreshFromStorefronts()

            log.notice("Migrating game vertical image storage.")

            for (key, url) in defaults.dictionaryRepresentation() where key.hasSuffix("_imageURL") {
                guard let url = url as? URL else { continue }

                let targetGameID: String = key.replacingOccurrences(of: "_imageURL", with: "")
                await MainActor.run {
                    guard let targetGame = Game.store.library.first(where: { $0.id == targetGameID }) else {
                        log.warning("Game with ID \(targetGameID) not found in store, skipping migration.")
                        return
                    }

                    // imageURLs must have been custom if stored in UD
                    // so it's safe to directly append to underlying property
                    targetGame._verticalImageURL = url
                }

                defaults.removeObject(forKey: key)
            }
        }

        static func migrateWideImageURLs() async {
            try? await Game.store.refreshFromStorefronts()

            log.notice("Migrating game horizontal image storage.")

            for (key, url) in defaults.dictionaryRepresentation() where key.hasSuffix("_wideImageURL") {
                guard let url = url as? URL else { continue }

                let targetGameID: String = key.replacingOccurrences(of: "_wideImageURL", with: "")
                await MainActor.run {
                    guard let targetGame = Game.store.library.first(where: { $0.id == targetGameID }) else {
                        log.warning("Game with ID \(targetGameID) not found in store, skipping migration.")
                        return
                    }

                    // wideImageURLs must have been custom if stored in UD
                    // so it's safe to directly append to underlying property
                    targetGame._horizontalImageURL = url
                }

                defaults.removeObject(forKey: key)
            }
        }
    }
}
