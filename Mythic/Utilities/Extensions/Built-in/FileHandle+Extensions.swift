//
//  FileHandle+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension FileHandle {
    /// A bridge for `readabilityHandler` callbacks, using AsyncStream, fetching `availableData`.
    /// - Note: This stream automatically handles empty handle data.
    var readabilityDataStream: AsyncStream<Data> {
        AsyncStream { continuation in
            self.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                
                // empty data means the handle's reached EOF
                guard !data.isEmpty else {
                    continuation.finish()
                    self?.readabilityHandler = nil
                    return
                }
                
                continuation.yield(data)
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.readabilityHandler = nil
            }
        }
    }
}

