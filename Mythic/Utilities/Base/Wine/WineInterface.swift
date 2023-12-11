//
//  Wine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 30/10/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
