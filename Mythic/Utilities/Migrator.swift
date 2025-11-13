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
/// Reinitialise redundant data structure.
final class Migrator {
    private static let log: Logger = .custom(category: "Migrator")
    private static let containerQueue = DispatchQueue(label: "containerMigration")

    /// Migrate redundant bottle format.
    /// Data migration from versions v0.1.1-alpha and below.
    static func migrateFromOldBottleFormatIfNecessary() {
        // Determines eligibility by searching for redundant UserDefaults key "allBottles".
        guard let data = defaults.data(forKey: "allBottles"),
              let decodedData = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]] else {
            return
        }

        containerQueue.sync {
            log.notice("Older bottle format detected, commencing bottle management system migration")

            var iterations = 0
            var convertedBottles: [Wine.Container] = .init()

            for (name, bottle) in decodedData {
                guard let urlArray = bottle["url"] as? [String: String], // unable to cast directly to URL.
                      let relativeURL = urlArray["relative"],
                      let url: URL = .init(string: relativeURL.removingPercentEncoding ?? relativeURL)
                else {
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

                iterations += 1

                log.log("converted \(url.prettyPath) (\(iterations)/\(decodedData.count))")
            }

            log.notice("Bottle management system migration complete.")
            defaults.removeObject(forKey: "allBottles")
        }
    }

    // MARK: >= 0.3.2 Bottle → Container migration
    /// Migrate Bottle → Container naming scheme.
    /// Data migration from versions v0.3.2 and below.
    /// This must be ran **before** the "launchCount" UserDefaults key is appended to.
    static func migrateBottleSchemeToContainerSchemeIfNecessary() {
        let oldScheme = Bundle.appContainer!.appending(path: "Bottles")
        let newScheme = Bundle.appContainer!.appending(path: "Containers")

        // Determines eligibility by checking for value not present in earlier versions
        guard defaults.dictionary(forKey: "launchCount") == nil else {
            return
        }

        log.notice("Commencing bottle → container scheme migration.")

        containerQueue.sync {
            do {
                try files.moveItem(at: oldScheme, to: newScheme)

                if let contents = try? files.contentsOfDirectory(at: newScheme, includingPropertiesForKeys: nil) {
                    for containerURL in contents {
                        log.debug("Migrating container object: \(String(describing: try? Wine.Container(knownURL: containerURL)))")
                    }
                }

                // Migrate bottleURLs to containerURLs
                if let bottleURLs = try? defaults.decodeAndGet([URL].self, forKey: "bottleURLs") {
                    let containerURLs = bottleURLs.map { bottleURL -> URL in
                        let currentPath = bottleURL.path(percentEncoded: false)
                        if currentPath.contains(oldScheme.path(percentEncoded: false)) {
                            let newPath = currentPath.replacingOccurrences(of: oldScheme.path(percentEncoded: false), with: newScheme.path(percentEncoded: false))
                            log.debug("Migrating bottle (modifying bottle URL from \(bottleURL) to \(newPath))...")
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
                            let newPath = currentPath.replacingOccurrences(of: oldScheme.path(percentEncoded: false), with: newScheme.path(percentEncoded: false))
                            filteredURL = URL(filePath: newPath)
                        } else {
                            filteredURL = currentURL
                        }

                        let gameKey = key.replacingOccurrences(of: "_bottleURL", with: "")
                        log.debug("Migrating game \(gameKey)'s container URL...")
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

    /// Data migration from versions v0.5.0 and below.
    static func migrateContainerURLDefinition(forGame game: Game) {
        let oldKey: String = game.id.appending("_containerURL")
        guard let containerURL = defaults.url(forKey: oldKey) else { return }

        log.info("Migrating container url definitions")

        defer {
            defaults.removeObject(forKey: oldKey)
            log.info("Migrated container url definitions.")
        }

        guard Wine.containerExists(at: containerURL) else {
            log.info("Container URL no longer applicable, container does not exist. Removing.")
            return
        }

        var containerURLs: [Game: URL] = (try? defaults.decodeAndGet([Game: URL].self, forKey: "gameContainerURLs")) ?? .init()
        containerURLs[game] = containerURL

        do {
            try defaults.encodeAndSet(containerURLs, forKey: "gameContainerURLs")
        } catch {
            log.error("Unable to complete container URL definition migration: \(error.localizedDescription)")
        }
    }

    /// Data migration from versions v0.5.0 and below.
    static func migrateGameLaunchArgumentDefinition(forGame game: Game) {
        let oldKey: String = game.id.appending("_launchArguments")
        guard let arguments = defaults.array(forKey: oldKey) as? [String] else { return }

        log.info("Migrating game launch argument definitions")

        defer {
            defaults.removeObject(forKey: oldKey)
            log.info("Migrated game launch argument definitions.")
        }

        guard game.isInstalled else {
            log.warning("Launch arguments no longer applicable, game is not installed anymore. Removing.")
            return
        }

        var launchArguments: [Game: [String]] = (try? defaults.decodeAndGet([Game: [String]].self, forKey: "gameLaunchArguments")) ?? .init()
        launchArguments[game] = arguments

        do {
            try defaults.encodeAndSet(launchArguments, forKey: "gameLaunchArguments")
        } catch {
            log.error("Unable to complete game launch argument definition migration: \(error.localizedDescription)")
        }
    }
}
