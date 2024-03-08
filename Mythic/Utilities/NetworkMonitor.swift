//
//  NetworkMonitor.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/2/2024.
//

// Reference: https://arc.net/l/quote/ivjknjyv

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
                    url: .init(string: "https://epicgames.com")!,
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
