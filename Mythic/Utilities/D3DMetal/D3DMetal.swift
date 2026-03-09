//
//  D3DMetal.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/3/2026.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

class D3DMetal {
    /// Install D3DMetal from a given directory.
    static func install(from directory: URL) throws {
        guard Engine.isInstalled else { throw Engine.NotInstalledError() }
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard isDirectory.boolValue else {
            throw POSIXError(.ENOTDIR)
        }
        
        let librarySubdirectory: URL = directory.appending(component: "lib")
        guard FileManager.default.fileExists(atPath: librarySubdirectory.appending(component: "external").path),
              FileManager.default.fileExists(atPath: librarySubdirectory.appending(component: "wine").path) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "The supplied D3DMetal folder is incomplete or invalid.")
            ])
        }
        
        let process: Process = .init()
        process.executableURL = .init(filePath: "usr/bin/ditto")
        process.arguments = [librarySubdirectory.path,
                             Engine.directory.appending(path: "wine/lib").path]
        
        try process.run()
        process.waitUntilExit()
        
        try process.checkTerminationStatus()
        
        let propertiesFile = Engine.directory.appending(path: "Properties.plist")
        var properties = try PropertyListDecoder().decode(Engine.InstallationProperties.self,
                                                          from: .init(contentsOf: propertiesFile))
        
        properties.isD3DMetalInstalled = true
        
        let encoder: PropertyListEncoder = .init()
        encoder.outputFormat = .xml
        try encoder.encode(properties).write(to: propertiesFile)
    }
}
