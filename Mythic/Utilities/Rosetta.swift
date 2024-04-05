//
//  Rosetta.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 31/3/2024.
//

import Foundation

class Rosetta {
    static var exists: Bool { files.fileExists(atPath: "/Library/Apple/usr/share/rosetta") }
    
    struct AgreementFailure: LocalizedError {
        var errorDescription: String? = """
        You failed to agree to the software license agreement. Rosetta 2 cannot be installed.
        A list of Apple SLAs may be found here: https://www.apple.com/legal/sla/
        """
    }
    
    static func install(agreeToSLA: Bool, completion: @escaping (Double) -> Void) async throws {
        guard agreeToSLA else { throw AgreementFailure() }
        
        let task = Process()
        task.launchPath = "/usr/sbin/softwareupdate"
        task.arguments = ["--install-rosetta", "--agree-to-license"]
        task.qualityOfService = .userInitiated
        
        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe
        
        try task.run()
        
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let line = String(data: handle.availableData, encoding: .utf8) else { return }
            if let match = try? Regex(#"Installing: (\d+(?:\.\d+)?)%"#).firstMatch(in: line) {
                completion(Double(match.last?.substring ?? .init()) ?? 0.0)
            }
        }
        
        task.waitUntilExit()
    }
}
