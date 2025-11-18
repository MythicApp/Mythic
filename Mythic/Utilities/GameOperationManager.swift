//
//  GameOperationManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

@Observable
final class GameOperationManager: Sendable {
    @MainActor static var shared: GameOperationManager = .init()
    internal static let log: Logger = .custom(category: "GameOperationManager")

    private var _queue: OperationQueue
    // necessitated by deprecation of `OperationQueue.operations`
    private(set) var queue: [GameOperation] = .init()

    init() {
        let queue: OperationQueue = .init()
        queue.name = "GameOperationManagerQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        self._queue = queue
    }

    func queueOperation(_ operation: GameOperation) {
        queue.append(operation)

        // remove operation from `queue` on completion, mirroring `_queue`
        operation.completionBlock = {
            Task { @MainActor in
                self.queue.removeAll(where: { $0 == operation })
            }
        }

        _queue.addOperation(operation)
    }
}
