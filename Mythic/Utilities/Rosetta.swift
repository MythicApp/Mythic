//
//  Rosetta.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 31/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

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
        var errorDescription: String? = String(localized: """
            You failed to agree to the software license agreement.
            As a result, Rosetta 2 cannot be installed.
            A list of Apple SLAs may be found here: https://www.apple.com/legal/sla/
            """)
    }

    static func install(
        agreeToSLA: Bool,
        percentageCompletion completion: @Sendable @escaping (Double) -> Void
    ) async throws {
        guard agreeToSLA else { throw AgreementFailure() }

        let task = Process()
        task.launchPath = "/usr/sbin/softwareupdate"
        task.arguments = ["--install-rosetta", "--agree-to-license"]
        task.qualityOfService = .userInitiated
        
        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe
        
        try task.run()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            // swiftlint:disable:next optional_data_string_conversion
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
