//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

// Copyright © 2023-2025 vapidinfinity

import Foundation
import Network
import SwiftUI

final class NetworkMonitor: ObservableObject, @unchecked Sendable {

    public static let shared: NetworkMonitor = .init()

    private let networkPathMonitor: NWPathMonitor = .init()
    private let queue = DispatchQueue(label: "network-monitor-queue")

    @MainActor @Published var isConnected: Bool = false
    @MainActor @Published var epicAccessibilityState: NetworkAccessibility?

    enum NetworkAccessibility {
        case accessible
        case checking
        case inaccessible
    }

    private init() {
        networkPathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            Task { @MainActor in
                self.isConnected = (path.status == .satisfied)

                if self.isConnected {
                    self.checkEpicAccessibility()
                }
            }
        }

        networkPathMonitor.start(queue: queue)
    }

    private func checkEpicAccessibility() {
        Task { @MainActor in
            self.epicAccessibilityState = .checking
        }

        let request = URLRequest(
            url: .init(string: "https://epicgames.com")!,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: .init(5)
        )

        let session = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            guard error == nil else { return }
            guard let response = response as? HTTPURLResponse else { return }

            let responseOK: Bool = (200...299).contains(response.statusCode)
            Task { @MainActor in
                self.epicAccessibilityState = responseOK ? .accessible : .inaccessible
            }
        }

        session.resume()
    }
}

#Preview {
    ContentView()
        .environmentObject(NetworkMonitor.shared)
}
