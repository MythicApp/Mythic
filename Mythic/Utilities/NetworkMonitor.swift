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
    @Published var isCheckingEpicAccessibility = false
    @Published var isEpicAccessible = true
    
    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            var epicURL: URLRequest = .init(url: .init(string: "https://epicgames.com")!)
            epicURL.timeoutInterval = 7
            
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                
                if self?.isConnected == true {
                    self?.isCheckingEpicAccessibility = true
                    URLSession.shared.dataTask(with: .init(string: "https://epicgames.com")!) { (_/*data*/, response, error) in
                        guard error == nil else { self?.isEpicAccessible = false; return }
                        guard let httpResponse = response as? HTTPURLResponse else { self?.isEpicAccessible = false; return }
                        DispatchQueue.main.async {
                            self?.isEpicAccessible = (200...299) ~= httpResponse.statusCode
                            self?.isCheckingEpicAccessibility = false
                        }
                    }.resume()
                } else {
                    DispatchQueue.main.async {
                        self?.isEpicAccessible = false
                        self?.isCheckingEpicAccessibility = false
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
