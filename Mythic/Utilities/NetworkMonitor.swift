//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")
    var isConnected = false

    init() {
        networkMonitor.pathUpdateHandler = { path in
            self.isConnected = (path.status == .satisfied)
            Task {
                await MainActor.run {
                    self.objectWillChange.send()
                }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
}
