//
//  FileManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/1/2025.
//

import Foundation

extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if files.fileExists(atPath: url.path) {
            try files.removeItem(at: url)
        }
    }
}
