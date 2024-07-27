//
//  Process.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/3/2024.
//

import Foundation

extension Process {
    @discardableResult
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
    
    static func executeAsync(_ executablePath: String, arguments: [String], completion: @escaping (Legendary.CommandOutput) -> Void) async throws {
        let process = Process()
        
        process.launchPath = executablePath
        process.arguments = arguments
        
        let stderr = Pipe()
        let stdout = Pipe()
        
        process.standardError = stdout
        process.standardOutput = stdout
        
        try? process.run()
        
        let output: Legendary.CommandOutput = .init()
        
        stderr.fileHandleForReading.readabilityHandler = { handle in
            output.stderr = String(decoding: handle.availableData, as: UTF8.self)
            completion(output) // ⚠️ FIXME: critical performance issues
        }
        
        stderr.fileHandleForReading.readabilityHandler = { handle in
            output.stdout = String(decoding: handle.availableData, as: UTF8.self)
            completion(output) // ⚠️ FIXME: critical performance issues
        }
    }
}
