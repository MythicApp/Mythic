//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import Network
import SwiftUI

final class NetworkMonitor: ObservableObject {

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
        .environmentObject(SparkleController())
}
