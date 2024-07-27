//
//  SteamInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 27/7/2024.
//

// Reference: https://developer.valvesoftware.com/wiki/SteamCMD

// TODO: steamcmd autoupdater parser
// TODO: use licenses_print to get all available games' IDs -- see steam-cli GH src for more ino
// TODO: onetap steam gui installer -- for DRM
// TODO: user-interactive shell?
// TODO: use find <command> to search for other commands -- steamcmd docs are literally nonexistent

import Foundation
import OSLog

final class Steam {
    internal static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "steam")
    
    static var installed: Bool {
        files.fileExists(atPath: directory.appending(path: "steamcmd").path(percentEncoded: false))
    }
    
    static let directory: URL = Bundle.appHome!.appending(path: "Steam")
    
    private static let steamcmd: URL = directory.appending(path: "steamcmd")
    
    static func install() async throws { // you can specify +login..., +whatever command... w/o using the steam shell
        if !files.fileExists(atPath: directory.path) {
            try files.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        
        try Process.execute("/bin/bash", arguments: ["-c", "curl -sqL \"https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz\" | tar zxvf - -C \(directory)"])
        
        if installed { /* return completion */ }
    }
    
    static func uninstall() throws {
        try files.removeItem(at: directory)
    }
}
