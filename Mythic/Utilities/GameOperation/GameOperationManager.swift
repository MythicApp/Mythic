//
//  GameOperationManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog
import Observation
import UserNotifications
import AppKit
import DockProgress

@Observable @MainActor final class GameOperationManager {
    static var shared: GameOperationManager = .init()
    private let log: Logger = .custom(category: "GameOperationManager")

    // ‼️ operationqueue should NOT be accessed outside, this will always be private
    // cannot name this _queue, swiftui seems to automatically insert _queue for the queue variable
    // avoid naming 'underlyingQueue', this is already a variable
    // swiftlint:disable:next identifier_name
    var _operationQueue: OperationQueue
    // necessitated by deprecation of `OperationQueue.operations`
    internal private(set) var queue: [GameOperation] = .init() {
        didSet {
            if let currentOperation = self.queue.first {
                Task { @MainActor in
                    DockProgress.style = .badge(color: .accentColor, badgeValue: { self.queue.count })
                    DockProgress.progressInstance = currentOperation.progressKVOBridge._progress
                }
            }
        }
    }

    private init() {
        let queue: OperationQueue = .init()
        queue.name = "GameOperationManagerQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        self._operationQueue = queue
    }

    private func removeFromOverlyingQueue(_ operation: GameOperation) {
        queue.removeAll(where: { $0 == operation })
    }

    func queueOperation(_ operation: GameOperation) {
        let originalCompletionBlock = operation.completionBlock
        operation.completionBlock = { [self] in
            // run code that was already in the completion block
            originalCompletionBlock?()

            // present any unhandled errors within the operation to the ui.
            Task { @MainActor in
                if let error = operation.error {
                    let alert = NSAlert()
                    alert.messageText = String(localized: "Unable to complete operation [\(operation.description)].")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: String(localized: "OK"))

                    if let window = NSApp.windows.first {
                        alert.beginSheetModal(for: window)
                    }
                }
            }

            // remove operation from `queue` on operation completion,
            // this ensures `queue` is always mirroring `operationQueue`.
            Task { await removeFromOverlyingQueue(operation) }

            // display completion notification to user
            Task {
                let notificationContent: UNMutableNotificationContent = .init()
                notificationContent.title = String(localized: "Operation complete.")
                notificationContent.body = String(localized: "\(operation.game.description) is now ready.")
                notificationContent.interruptionLevel = .active

                let notificationRequest: UNNotificationRequest = .init(
                    identifier: "\(operation.id)_operationCompletion",
                    content: notificationContent,
                    trigger: nil
                )

                do {
                    try await notifications.add(notificationRequest)
                } catch {
                    log.error("Unable to send notification for operation completion: \(error.localizedDescription)")
                }
            }

            log.debug("Operation \(operation.debugDescription) complete.")
        }

        _operationQueue.addOperation(operation)
        queue.append(operation)

        log.debug("Queued operation \(operation.debugDescription)")
    }

    // convenience overload that avoids direct `GameOperation` instantiation
    func queueOperation(game: Game,
                        type: GameOperation.ActiveOperationType,
                        function: @escaping (Progress) async throws -> Void) {
        queueOperation(
            .init(game: game,
                  type: type,
                  function: function)
        )
    }

    func cancelAllOperations() {
        log.debug("Cancelling all (\(self.queue.count)) operations.")
        _operationQueue.cancelAllOperations()
        queue.removeAll()
        log.debug("Cancelled all operations, and cleared queues.")
    }
}
