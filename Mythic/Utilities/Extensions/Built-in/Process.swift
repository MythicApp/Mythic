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
        let task = Process()
        task.launchPath = executablePath
        task.arguments = arguments
        
        let stdout: Pipe = .init()
        let stderr: Pipe = .init()
        
        task.standardOutput = stdout
        task.standardError = stderr
        
        try task.run()
        task.waitUntilExit()
        
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        
        return output
    }
    
    static func executeAsync(_ executablePath: String, arguments: [String], completion: @escaping (Legendary.CommandOutput) -> Void) async throws {
        let task = Process()
        
        task.launchPath = executablePath
        task.arguments = arguments
        
        let stderr = Pipe()
        let stdout = Pipe()
        
        task.standardError = stdout
        task.standardOutput = stdout
        
        try task.run()
        
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
