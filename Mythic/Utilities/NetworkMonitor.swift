//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

import Foundation
import Network

import SwiftUI

@Observable class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected = true
    var isCheckingEpicAccessibility = false
    var isEpicAccessible = true

    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                guard self?.isConnected == true else { self?.updateAccessibility(false); return }
                
                self?.isCheckingEpicAccessibility = true
                
                let request = URLRequest(
                    url: URL(string: "https://epicgames.com")!,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                    timeoutInterval: 5
                )
                
                URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                    guard error == nil, let httpResponse = response as? HTTPURLResponse else { self?.updateAccessibility(false); return }
                    self?.updateAccessibility((200...299) ~= httpResponse.statusCode)
                }.resume()
                
            }
        }
        networkMonitor.start(queue: queue)
    }

    private func updateAccessibility(_ isAccessible: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isEpicAccessible = isAccessible
            self?.isCheckingEpicAccessibility = false
        }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
