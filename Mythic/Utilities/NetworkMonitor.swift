//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

// Copyright © 2023-2026 vapidinfinity

import Foundation
import Network
import SwiftUI

final class NetworkMonitor: ObservableObject, @unchecked Sendable {
    static let shared: NetworkMonitor = .init()

    private let monitor: NWPathMonitor = .init()
    private let queue: DispatchQueue = .init(label: "NetworkMonitor", qos: .background)

    @MainActor @Published private(set) var isConnected: Bool = false

    @MainActor @Published private(set) var epicAccessibilityState: NetworkAccessibility?
    enum NetworkAccessibility {
        case accessible
        case checking
        case inaccessible
    }

     private init() {
         monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            Task { @MainActor in
                self.isConnected = (path.status == .satisfied)

                if self.isConnected {
                    try? await self.checkEpicAccessibility()
                }
            }
        }

         monitor.start(queue: queue)
    }

    private func checkEpicAccessibility() async throws {
        await MainActor.run {
            self.epicAccessibilityState = .checking
        }

        let request = URLRequest(
            url: .init(string: "https://epicgames.com")!,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: .init(5)
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        await MainActor.run {
            self.epicAccessibilityState = (200...299).contains(httpResponse.statusCode) ? .accessible : .inaccessible
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NetworkMonitor.shared)
}
