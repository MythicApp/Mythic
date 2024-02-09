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
    private let workerQueue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected = true // Assumes the user is connected by default
    @Published var isEpicAccessible = true
    
    init() {
        networkMonitor.pathUpdateHandler = { [self] path in
            DispatchQueue.main.sync {
                isConnected = (path.status == .satisfied)
            }
            
            DispatchQueue.main.sync {
                if isConnected {
                    URLSession.shared.dataTask(with: .init(string: "https://epicgames.com")!) { [self] (_, response, _) in
                        isEpicAccessible = ((200...299) ~= ((response as? HTTPURLResponse)?.statusCode ?? .init()))
                    }.resume()
                } else {
                    isEpicAccessible = false
                }
            }
        }
        
        networkMonitor.start(queue: workerQueue)
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
