//
//  FileManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/1/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if files.fileExists(atPath: url.path) {
            try files.removeItem(at: url)
        }
    }

    func forceCopyItem(at sourceURL: URL, to destinationURL: URL) throws {
        let result = try Process.execute(
            executableURL: .init(filePath: "/bin/cp"),
            arguments: [
                "-f",
                sourceURL.path(percentEncoded: false),
                destinationURL.path(percentEncoded: false)
            ]
        )

        if !result.standardError.isEmpty {
            throw ForceCopyFailedError()
        }
    }

    func createUniqueTemporaryDirectory() throws -> URL {
        let temporaryDirectory = temporaryDirectory.appending(path: "Mythic/\(UUID().uuidString)")
        try createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        return temporaryDirectory
    }

    /// An error indicating that force-copying files has failed.
    struct ForceCopyFailedError: LocalizedError {
        var errorDescription: String? = "Failed to force-copy files."
    }
}
