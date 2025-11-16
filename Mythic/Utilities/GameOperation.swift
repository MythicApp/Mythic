//
//  GameOperation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

@Observable final class GameOperationManager: ObservableObject {
    @MainActor static var shared: GameOperationManager = .init()

    internal static let log: Logger = .custom(category: "GameOperationManager")

    var queueStore: QueueStore = .init()
}

extension GameOperationManager {
    actor QueueStore {
        // swiftlint:disable:next identifier_name
        private(set) var _queue: [GameOperation] = .init()
        var currentOperation: GameOperation? { _queue.first }

        private var loop: Task<Sendable, Error>?

        func add(_ operation: GameOperation) {
            _queue.append(operation)
        }

        private func startOperationLoop() async {
            guard loop == nil else { return }
            loop = .init(operation: { await taskLoop() })

            func taskLoop() async {
                while !_queue.isEmpty {
                    let operation = _queue.removeFirst()
                    if operation._task == nil {
                        await operation.startTask()
                    }
                }
            }
        }

        func remove(_ operation: GameOperation) {
            _queue.removeAll(where: { $0 == operation })
        }

        func fetchQueue() -> [GameOperation] { return _queue }
    }
}

// FIXME: The use of `@unchecked Sendable` is technically safe at present moment.
// FIXME: This may change, and should be properly implemented in the future.

final class GameOperation: Identifiable, @unchecked Sendable {
    let id: UUID = .init()
    let game: Game
    let type: OperationType
    let function: @Sendable () async throws -> Sendable

    private(set) var status: OperationStatus = .pending
    private(set) var _task: Task<Sendable, Error>? = nil

    init(game: Game,
         type: OperationType,
         function: @Sendable @escaping () async throws -> Sendable,
         status: OperationStatus,
         task: Task<Sendable, Error>? = nil) {
        self.game = game
        self.type = type
        self.function = function
        self.status = status
        self._task = task
    }

    func startTask() async {
        self._task = .init(operation: function)
        self.status = .inProgress

        do {
            _ = try await self._task?.value
            self.status = .completed
        } catch {
            self.status = .failed
        }
    }
}

extension GameOperation: Equatable {
    static func == (lhs: GameOperation,
                    rhs: GameOperation) -> Bool {
        return lhs.id == rhs.id
    }
}

extension GameOperation {
    enum OperationType {
        case downloading
        case installing
        case updating
        case uninstalling
        case verifying
        case launching
    }

    enum OperationStatus {
        case pending
        case inProgress
        case completed
        case failed
    }
}
