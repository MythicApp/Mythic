//
//  Wine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 30/10/2023.
//

import Foundation
import OSLog

private let files = FileManager.default

class Wine {

    @available(*, message: "Not implemented.")
    static func command() {

    }

    static let bottlesDirectory = {
        let directory = Bundle.appContainer!.appending(path: "Bottles")
        if !files.fileExists(atPath: directory.path) {
            do {
                try files.createDirectory(at: directory, withIntermediateDirectories: false)
                Logger.file.info("Creating bottles directory")
            } catch {
                Logger.app.error("Error creating Bottles directory: \(error)")
            }
        }

        return directory
    }

    func createBottle(name: String) {
        guard Libraries.isInstalled() else { return }
        // run wineboot
    }
}
