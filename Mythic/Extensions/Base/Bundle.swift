//
//  Bundle.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/9/2023.
//

import Foundation
import OSLog

/// Add some much-needed extensions to Bundle, including references to a dedicated application support folder for Mythic.
extension Bundle {
    
    /// The current user's application support directory.
    static let userAppSupport: String = {
        let libraryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
        return libraryPath
    }()
    
    /// Dedicated 'Mythic' Application Support Folder
    static let appHome: String = {
        let appHomePath = "\(userAppSupport)/\(Bundle.main.infoDictionary?["CFBundleDisplayName"] as! String)"
        
        if !FileManager.default.fileExists(atPath: appHomePath) {
            do {
                try FileManager.default.createDirectory(atPath: appHomePath, withIntermediateDirectories: true, attributes: nil)
                Logger.app.info("Creating application support directory")
            } catch {
                Logger.app.error("Error creating application support directory: \(error)")
            }
        }
        return appHomePath
    }()
}
