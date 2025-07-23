//
//  PersistentStateMigrator.swift
//  Mythic
//

import Foundation

// TODO: recentlyPlayed,

/*
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
     <key>id</key>
     <string>44475B9A-C001-4BA0-8C08-6051D3A4FA40</string>
     <key>name</key>
     <string>Default</string>
     <key>propertiesFile</key>
     <dict>
         <key>relative</key>
         <string>file:///Users/jiecheng/Library/Containers/xyz.blackxfiied.Mythic/Containers/Default/properties.plist</string>
     </dict>
     <key>settings</key>
     <dict>
         <key>avx2</key>
         <true/>
         <key>dxvk</key>
         <false/>
         <key>dxvkAsync</key>
         <false/>
         <key>metalHUD</key>
         <false/>
         <key>msync</key>
         <true/>
         <key>retinaMode</key>
         <true/>
         <key>scaling</key>
         <integer>192</integer>
         <key>windowsVersion</key>
         <string>11</string>
     </dict>
     <key>url</key>
     <dict>
         <key>relative</key>
         <string>file:///Users/jiecheng/Library/Containers/xyz.blackxfiied.Mythic/Containers/Default</string>
     </dict>
 </dict>
 </plist>
 */

public struct PersistentStateMigrator {
    public static let logger = AppLoggerModel(category: Self.self)
    // All the keys EXCEPT sparkle and WhatsNewKit.
    private static let defaultKeys = [
        "containerURLs",
        "discordRPC",
        "engineAutomaticallyChecksForUpdates",
        "engineBranch",
        "epicGamesWebDataStoreIdentifierString",
        "gameCardBlur",
        "gameCardSize",
        "installBaseURL",
        "isLibraryGridScrollingVertical",
        "isOnboardingPresented",
        "launchCount",
        "minimiseOnGameLaunch",
        "quitOnAppClose"
    ]
    private static let sparkleDefaultKeys = [
        "SUAutomaticallyUpdate",
        "SUEnableAutomaticChecks"
    ]
    
    
    static let wineContainersBasePath = DirectoriesUtility
        .containerDirectory?.appending(path: "Containers")
    private typealias ContainersURLsValue = [URL]
    private struct WineContainerProperties: Decodable {
        let id: String?
        let name: String?
        let settings: Settings?
        
        struct Settings: Decodable {
            enum WindowsVersion: String, Decodable, CaseIterable {
                public var storableWindowsVersion: WineContainersV1PersistentStateModel.WindowsVersion {
                    switch self {
                    case .windows11: return .windows11
                    case .windows10: return .windows10
                    case .windows8_1: return .windows8Point1
                    case .windows8: return .windows8
                    case .windows7: return .windows7
                    case .windowsVista: return .windowsVista
                    case .windowsXp: return .windowsXP64Bit
                    case .windows98: return .windowsXP64Bit // Why did we even support this?
                    }
                }
                
                case windows11 = "11"
                case windows10 = "10"
                case windows8_1 = "8.1"
                case windows8 = "8"
                case windows7 = "7"
                case windowsVista = "Vista"
                case windowsXp = "XP"
                case windows98 = "98"
            }

            let avx2: Bool?
            let dxvk: Bool?
            let dxvkAsync: Bool?
            let metalHUD: Bool?
            let msync: Bool?
            let retinaMode: Bool?
            let scaling: Int?
            let windowsVersion: WindowsVersion?
        }
    }

    public static func checkRequiresMigration() -> Bool {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        
        // Check if any key starts with WhatsNewKit
        if keys.contains(where: { $0.hasPrefix("WhatsNewKit.") }) {
            logger.debug("Found WhatsNewKit keys, requiring migration.")
            return true
        }
        
        // Check default keys.
        let defaultKeysSet = Set(PersistentStateMigrator.defaultKeys)
        for key in keys {
            if defaultKeysSet.contains(key) {
                logger.debug("Found default key \(key), requiring migration.")
                return true
            }
        }
        
        return false
    }
    
    private static func removeKeys(keys: [String:Any].Keys?) {
        let allKeys = keys ?? UserDefaults.standard.dictionaryRepresentation().keys
        
        let defaultKeysSet = Set(PersistentStateMigrator.defaultKeys)
        let sparkleKeysSet = Set(PersistentStateMigrator.sparkleDefaultKeys)
        for key in allKeys {
            if defaultKeysSet.contains(key) || sparkleKeysSet.contains(key) || key.starts(with: "WhatsNewKit.") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    @MainActor private static func updateContainters(data: [URL]) {
        guard let oldWineContainersBasePath = wineContainersBasePath else {
            // If this fails, we should crash.
            fatalError("PersistentStateMigrator: wineContainerBaseDirectoryURL nil.")
        }
        guard let newWineContainersBasePath = WineContainerManagerModel.wineContainersBasePath else {
            // If this fails, we should crash.
            fatalError("PersistentStateMigrator: wineContainersBasePath nil.")
        }
    
        for i in 0...data.count {
            let url = data[i]
            let propertiesURL = url.appending(path: "properties.plist")

            // Try parse data.
            if !FileManager.default.fileExists(atPath: propertiesURL.path) {
                logger.error("parseContainters: properties does not exist... skipping: \(url) .")
                continue
            }
            var data: Data
            do {
                data = try Data(contentsOf: propertiesURL)
            } catch {
                logger.error("updateContainters: failed to read data from \"\(propertiesURL)\": \(error).")
                break
            }
            var properties: WineContainerProperties
            do {
                properties = try PropertyListDecoder().decode(WineContainerProperties.self, from: data)
            } catch {
                logger.error("updateContainters: failed to parse data from \"\(propertiesURL)\": \(error).")
                break
            }
            
            // Check if the directory is in the wineContainerBaseDirectory
            let shared = WineContainersV1PersistentStateModel.shared
            let inOldDirectory = url.absoluteString.hasPrefix(oldWineContainersBasePath.absoluteString)
            var folderDir = url
            let id = UUID(uuidString: properties.id ?? "") ?? UUID()
            let isDefault = i == 0
            
            if inOldDirectory {
                folderDir = newWineContainersBasePath
                    .appending(path: id.uuidString)
                do {
                    try FileManager.default.moveItem(at: url, to: folderDir)
                } catch {
                    logger.error("updateContainters: failed to move data for \"\(url)\": \(error).")
                    break
                }
            }
            if isDefault {
                shared.store.defaultContainerID = id
            }
            
            // Add the data to the new system.
            let container = WineContainersV1PersistentStateModel.WineContainer(
                containerID: id,
                name: properties.name ?? "Bottle \(i)",
                path: folderDir,
                windowsVersion: properties.settings?.windowsVersion?.storableWindowsVersion ?? .windows10,
                windowsBuild: 22000,
                retinaMode: properties.settings?.retinaMode ?? false,
                dpiScaling: properties.settings?.scaling ?? 96,
                syncType: (properties.settings?.msync ?? true ? .machSync : .enhancedSync),
                exposeAVX: properties.settings?.avx2 ?? false,
                direct3DTranslationLayer:.direct3DMetal,
                metalHUDEnabled: false,
                metalTracingEnabled: properties.settings?.metalHUD ?? false,
                direct3DMetalDirectXRaytracingEnabled: false,
                dxvkAsyncEnabled: false,
                dxvkHUD: .none,
                discordRPCPassthrough: true
            )
            
        }
    }
    
    @MainActor public static func preformMigration() {
        let shared = AppSettingsV1PersistentStateModel.shared

        // Sparkle
        let sparkleAutomaticallyUpdate = UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") as? Bool
        let sparkleEnableAutomaticChecks = UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") as? Bool
        if sparkleAutomaticallyUpdate == true {
            logger.debug("sparkleUpdateAction: Install.")
            shared.store.sparkleUpdateAction = .install
        } else if sparkleEnableAutomaticChecks == true {
            logger.debug("sparkleUpdateAction: Check.")
            shared.store.sparkleUpdateAction = .check
        } else {
            logger.debug("sparkleUpdateAction: Not Found.")
        }
        
        // quitOnAppClose
        let quitOnAppClose = UserDefaults.standard.object(forKey: "quitOnAppClose") as? Bool
        if let quitOnAppClose {
            logger.debug("closeGamesOnQuit: \(quitOnAppClose).")
            shared.store.closeGamesOnQuit = quitOnAppClose
        } else {
            logger.debug("closeGamesOnQuit: Not Found.")
        }
        
        // installBaseURL
        let installBaseURL = UserDefaults.standard.object(forKey: "installBaseURL") as? String
        if let installBaseURL, let installBaseURLParse = URL(string: installBaseURL) {
            shared.store.gameStorageDirectory = installBaseURLParse
            logger.debug("installBaseURL: \(installBaseURLParse) .")
        } else {
            logger.debug("installBaseURL: Not Found or Invalid.")
        }
        
        // engineBranch
        let engineBranch = UserDefaults.standard.object(forKey: "engineBranch") as? String
        if let engineBranch {
            switch engineBranch {
            case "7.7":
                shared.store.engineReleaseBranch = .stable
                logger.debug("engineReleaseBranch: Stable.")
            case "staging":
                shared.store.engineReleaseBranch = .development
                logger.debug("engineReleaseBranch: Development.")
            default: logger.debug("engineReleaseBranch: Unknown value \"\(engineBranch)\".")
            }
        } else {
            logger.debug("engineReleaseBranch: Not Found.")
        }
        
        // isOnboardingPresented
        let isOnboardingPresented = UserDefaults.standard.object(forKey: "isOnboardingPresented") as? Bool
        if let isOnboardingPresented {
            shared.store.inOnboarding = isOnboardingPresented
            logger.debug("inOnboarding: \(isOnboardingPresented).")
        } else {
            logger.debug("inOnboarding: Not Found.")
        }
        
        // minimiseOnGameLaunch
        let minimiseOnGameLaunch = UserDefaults.standard.object(forKey: "minimiseOnGameLaunch") as? Bool
        if let minimiseOnGameLaunch {
            shared.store.hideOnGameLaunch = minimiseOnGameLaunch
            logger.debug("hideOnGameLaunch: \(minimiseOnGameLaunch).")
        } else {
            logger.debug("hideOnGameLaunch: Not Found.")
        }
        
        // discordRPC
        let discordRPC = UserDefaults.standard.object(forKey: "discordRPC") as? Bool
        if let discordRPC {
            shared.store.enableDiscordRichPresence = discordRPC
            logger.debug("enableDiscordRichPresence: \(discordRPC).")
        } else {
            logger.debug("enableDiscordRichPresence: Not Found.")
        }
        
        // engineAutomaticallyChecksForUpdates
        let engineAutomaticallyChecksForUpdates = UserDefaults.standard.object(forKey: "engineAutomaticallyChecksForUpdates") as? Bool
        if let engineAutomaticallyChecksForUpdates {
            shared.store.engineUpdateAction = engineAutomaticallyChecksForUpdates ? .check : .off
            logger.debug("engineUpdateAction: \(engineAutomaticallyChecksForUpdates ? "Check" : "Off").")
        } else {
            logger.debug("engineUpdateAction: Not Found.")
        }
        
        // containerURLs
        let containerURLs = UserDefaults.standard.object(forKey: "containerURLs") as? Data
        if let containerURLs {
            do {
                let decodedContainerURLs = try PropertyListDecoder().decode(ContainersURLsValue.self, from: containerURLs)
                updateContainters(data: decodedContainerURLs)
            } catch {
                logger.error("containerURLs: [URL] decoding failed: \(error)")
            }
        } else {
            logger.debug("containerURLs: Not Found.")
        }
    }
}
