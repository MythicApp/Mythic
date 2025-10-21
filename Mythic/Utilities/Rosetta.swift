//
//  Rosetta.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 31/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

final class Rosetta {
    static var exists: Bool { // thread-blocking, but ~0.04 sec cpu time
        let result = try? Process.execute(
            executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["oahd"]
        )

        return result?.standardOutput.isEmpty == false
    }

    struct AgreementFailure: LocalizedError {
        var errorDescription: String? = """
        Rosetta 2 cannot be installed, you failed to agree to the software license agreement.
        A list of Apple SLAs may be found here: https://www.apple.com/legal/sla/
        """
    }
    
    static func install(agreeToSLA: Bool, percentageCompletion completion: @escaping (Double) -> Void) async throws {
        guard agreeToSLA else { throw AgreementFailure() }
        
        let task = Process()
        task.launchPath = "/usr/sbin/softwareupdate"
        task.arguments = ["--install-rosetta", "--agree-to-license"]
        task.qualityOfService = .userInitiated
        
        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe
        
        try task.run()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let line = String(decoding: handle.availableData, as: UTF8.self)
            if let match = try? Regex(#"Installing: (\d+(?:\.\d+)?)%"#).firstMatch(in: line) {
                completion(Double(match.last?.substring ?? .init()) ?? 0.0)
            } else if line.contains("Install of Rosetta 2 finished successfully") {
                completion(100.0)
            }
        }
        
        task.waitUntilExit()
    }
}
