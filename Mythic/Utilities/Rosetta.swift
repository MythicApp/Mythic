//
//  Rosetta.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 31/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

final class Rosetta {
    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(
            atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
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

        let process: Process = .init()
        process.executableURL = .init(filePath: "/usr/sbin/softwareupdate")
        process.arguments = ["--install-rosetta", "--agree-to-license"]

        for try await chunk in process.runStreamed() {
            guard case .standardOutput = chunk.stream else { continue }

            if let match = try? Regex(#"Installing: (\d+(?:\.\d+)?)%"#).firstMatch(in: chunk.output) {
                completion(Double(match.last?.substring ?? .init()) ?? 0.0)
            } else if chunk.output.contains("Install of Rosetta 2 finished successfully") {
                completion(100.0)
            }
        }
    }
}
