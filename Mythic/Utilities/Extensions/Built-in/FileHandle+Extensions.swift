//
//  FileHandle+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension FileHandle {
    /// A bridge for `readabilityHandler` callbacks, using AsyncStream.
    /// - Note: This stream automatically handles empty handle data.
    var readabilityStream: AsyncStream<FileHandle> {
        AsyncStream { continuation in
            self.readabilityHandler = { handle in
                // empty data means the handle's reached EOF
                // FIXME: is this the case all the time?
                guard !handle.availableData.isEmpty else { continuation.finish(); return }
                
                continuation.yield(handle)
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.readabilityHandler = nil
            }
        }
    }
}
