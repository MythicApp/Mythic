//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

// MARK: - Copyright
// Copyright © 2023 blackxfiied

import Foundation
import Network
import SwiftUI

@Observable
final class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected = true
    private var _isCheckingEpicAccessibility = false
    var isEpicAccessible = true

    var isCheckingEpicAccessibility: Bool {
        _isCheckingEpicAccessibility
    }

    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self, !self.isCheckingEpicAccessibility else { return }
            self.isConnected = (path.status == .satisfied)
            guard self.isConnected else { self.updateAccessibility(false); return }

            self._isCheckingEpicAccessibility = true

            let request = URLRequest(
                url: URL(string: "https://epicgames.com")!,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 5
            )

            URLSession.shared.dataTask(with: request) { _, response, error in
                let isAccessible = error == nil,
                    isHTTPResponse = response as? HTTPURLResponse,
                    isSuccess = isHTTPResponse.map { (200...299).contains($0.statusCode) } ?? false
                self.updateAccessibility(isAccessible && isSuccess)
            }.resume()
        }
        networkMonitor.start(queue: queue)
    }

    private func updateAccessibility(_ isAccessible: Bool) {
        Task { @MainActor in
            isEpicAccessible = isAccessible
            _isCheckingEpicAccessibility = false
        }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
        .environmentObject(SparkleController())
}
