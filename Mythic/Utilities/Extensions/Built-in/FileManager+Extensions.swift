//
//  FileManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/1/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation

extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func forceCopyItem(at sourceURL: URL, to destinationURL: URL) throws {
        let process: Process = .init()
        process.executableURL = .init(filePath: "/bin/cp")
        process.arguments = [
            "-f",
            sourceURL.path(percentEncoded: false),
            destinationURL.path(percentEncoded: false)
        ]

        try process.run()
        process.waitUntilExit()

        try process.checkTerminationStatus()
    }

    func createUniqueTemporaryDirectory() throws -> URL {
        let temporaryDirectory = temporaryDirectory.appending(path: "Mythic/\(UUID().uuidString)")
        try createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        return temporaryDirectory
    }

    /// An error indicating that force-copying files has failed.
    struct ForceCopyFailedError: LocalizedError {
        var errorDescription: String? = String(localized: "Failed to force-copy files.")
    }
}
