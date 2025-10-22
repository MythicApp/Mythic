//
//  Migrator.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/4/2025.
//

import Foundation
import OSLog

/// Reinitialise redundant data structure.
final class Migrator {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Migrator"
    )

    private static let containerQueue = DispatchQueue(label: "containerMigration")

    /// Migrate redundant bottle format.
    /// Affects migrators from versions below v0.2.0.
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

                var settings: Wine.ContainerSettings = .init()
                guard let oldSettings = bottle["settings"] as? [String: Bool] else {
                    Logger.file.warning("Unable to read old bottle settings; using default")
                    continue
                }

                settings.metalHUD = oldSettings["metalHUD"] ?? settings.metalHUD
                settings.msync = oldSettings["msync"] ?? settings.msync
                settings.retinaMode = oldSettings["retinaMode"] ?? settings.retinaMode

                convertedBottles.append(.init(name: name, url: url, settings: settings))
                Wine.containerURLs.insert(url)

                iterations += 1

                Logger.app.log("converted \(url.prettyPath()) (\(iterations)/\(decodedData.count))")
            }

            Logger.file.notice("Bottle management system migration complete.")
            defaults.removeObject(forKey: "allBottles")
        }
    }

    // MARK: >= 0.3.2 Bottle → Container migration
    /// Migrate Bottle → Container naming scheme.
    /// Affects migrators from versions below v0.4.0.
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
                        Logger.app.debug("Migrating container object: \(String(describing: Wine.Container(knownURL: containerURL)))")
                    }
                }

                // Migrate bottleURLs to containerURLs
                if let bottleURLs = try? defaults.decodeAndGet([URL].self, forKey: "bottleURLs") {
                    let containerURLs = bottleURLs.map { bottleURL -> URL in
                        let currentPath = bottleURL.path(percentEncoded: false)
                        if currentPath.contains(oldScheme.path(percentEncoded: false)) {
                            let newPath = currentPath.replacingOccurrences(of: oldScheme.path(percentEncoded: false), with: newScheme.path(percentEncoded: false))
                            Logger.app.debug("Migrating bottle (modifying bottle URL from \(bottleURL) to \(newPath))...")
                            return URL(fileURLWithPath: newPath)
                        } else {
                            return bottleURL
                        }
                    }

                    do {
                        try defaults.encodeAndSet(containerURLs, forKey: "containerURLs")
                        defaults.removeObject(forKey: "bottleURLs")
                    } catch {
                        Logger.app.error("Unable to re-encode default 'bottleURLs' as 'containerURLs': \(error.localizedDescription)")
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
                            filteredURL = URL(fileURLWithPath: newPath)
                        } else {
                            filteredURL = currentURL
                        }

                        let gameKey = key.replacingOccurrences(of: "_bottleURL", with: "")
                        Logger.app.debug("Migrating game \(gameKey)'s container URL...")
                        defaults.set(filteredURL, forKey: key.replacingOccurrences(of: "_bottleURL", with: "_containerURL"))
                        defaults.removeObject(forKey: key)
                    }

                Logger.app.notice("Container renaming complete.")
            } catch {
                Logger.app.error("Unable to rename Bottles to Containers: \(error.localizedDescription) -- Mythic may not function correctly.")
            }
        }
    }

    /// Updates containers without a default scale set.
    /// Affects migrators from versions below v0.4.0.
    static func updateContainerScalingIfNecessary() async {
        // If scaling value is 0, it does not have a default scale set.
        for container in Wine.containerObjects where container.settings.scaling == 0 {
            let defaultScale = Wine.ContainerSettings().scaling
            
            await Wine.setDisplayScaling(containerURL: container.url, dpi: defaultScale)
            container.settings.scaling = defaultScale
        }
    }

    // MARK: <0.3.2 Config folder rename (Config → Epic)
    /// Rename Legendary configuration folder.
    /// Affects migrators from versions below v0.4.0.
    static func migrateEpicFolderNaming() {
        let legendaryOldConfig: URL = Bundle.appHome!.appending(path: "Config")
        if files.fileExists(atPath: legendaryOldConfig.path) {
            try? files.moveItem(at: legendaryOldConfig, to: Legendary.configurationFolder)
        }
    }
}
