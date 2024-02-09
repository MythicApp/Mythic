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

class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected = true // Assumes the user is connected by default
    @Published var isEpicAccessible = true
    
    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                
                if self?.isConnected == true {
                    URLSession.shared.dataTask(with: URL(string: "https://epicgames.com")!) { [weak self] (_, response, _) in
                        DispatchQueue.main.async {
                            self?.isEpicAccessible = ((200...299) ~= ((response as? HTTPURLResponse)?.statusCode ?? 0))
                        }
                    }.resume()
                } else {
                    DispatchQueue.main.async {
                        self?.isEpicAccessible = false
                    }
                }
            }
        }
        
        networkMonitor.start(queue: queue)
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
