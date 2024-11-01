//
//  Process.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/3/2024.
//

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
