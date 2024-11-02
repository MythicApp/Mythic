//
//  Process.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

extension Process {
    static func execute(_ executablePath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.launchPath = executablePath
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func executeAsync(_ executablePath: String, arguments: [String], completion: @escaping (CommandOutput) -> Void) async throws {
        let process = Process()
        process.launchPath = executablePath
        process.arguments = arguments
        
        let stderr = Pipe()
        let stdout = Pipe()
        
        process.standardError = stdout
        process.standardOutput = stdout
        
        try? process.run()
        
        let output: CommandOutput = .init()
        let outputQueue: DispatchQueue = .init(label: "genericProcessOutputQueue")

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty else { return }

            outputQueue.async {
                output.stderr = availableOutput
                completion(output)
                // log.debug("[command] [stderr] \(availableOutput)")
            }
        }
        
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty else { return }

            outputQueue.async {
                output.stdout = availableOutput
                completion(output)
                // log.debug("[command] [stdout] \(availableOutput)")
            }
        }
    }
}
