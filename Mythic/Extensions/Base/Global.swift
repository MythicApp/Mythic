//
//  Global.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/2023.
//

import Foundation

func isAppInstalled(bundleIdentifier: String) -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = [
        "bash", "-c",
        "mdfind \"kMDItemCFBundleIdentifier == '\(bundleIdentifier)'\""
    ]

    let stdout = Pipe()
    process.standardOutput = stdout
    process.launch()

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String()

    return !output.isEmpty
}
