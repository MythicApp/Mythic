//
//  GameOperation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import DockProgress
import OSLog

@Observable final class GameOperation: Operation, Identifiable, @unchecked Sendable {
    private var log: Logger { .custom(category: "GameOperation") }

    let id: UUID = .init()
    let game: Game
    let type: ActiveOperationType
    private let _progress: Progress
    private(set) var progressKVOBridge: ProgressKVOBridge

    let function: (Progress) async throws -> Void

    var error: Error?

    init(game: Game,
         type: ActiveOperationType,
         progress: Progress = .init(),
         function: @escaping (Progress) async throws -> Void) {
        self.game = game
        self.type = type
        self._progress = progress
        self.progressKVOBridge = .init(progress: progress)
        self.function = function

        // initialise `Operation`
        super.init()
    }

    // MARK: `Operation` inheritance overrides
    override func start() {
        Task(priority: .utility) {
            defer {
                isExecuting = false
                isFinished = true
            }

            guard !isCancelled else { return }

            do {
                isExecuting = true
                try await function(_progress)
            } catch {
                self.error = error
                log.error("Error occurred in operation \(self.debugDescription): \(error.localizedDescription).")
            }
        }
    }

    override var isAsynchronous: Bool { true }

    private var _isExecuting = false
    override private(set) var isExecuting: Bool {
        get { _isExecuting }
        set { // + KVO awareness, to spec
            willChangeValue(for: \.isExecuting)
            _isExecuting = newValue
            didChangeValue(for: \.isExecuting)
        }
    }

    private var _isFinished = false
    override private(set) var isFinished: Bool {
        get { _isFinished }
        set { // + KVO awareness, to spec
            willChangeValue(for: \.isFinished)
            _isFinished = newValue
            didChangeValue(for: \.isFinished)
        }
    }
}

extension GameOperation {
    override var description: String { "\(type) \(game)" }
    override var debugDescription: String { "[\(id)] \(type) for game \(game.debugDescription)" }
}

// MARK: - Types

extension GameOperation {
    enum ActiveOperationType {
        case download
        case install
        case repair
        case update
        case move
        case uninstall
        case launch
    }

    enum OperationType {
        case install
        case update
        case repair
    }
}

extension GameOperation.ActiveOperationType: CustomStringConvertible {
    var description: String {
        switch self {
        case .download:     String(localized: "Downloading")
        case .install:      String(localized: "Installing")
        case .repair:       String(localized: "Repairing")
        case .update:       String(localized: "Updating")
        case .move:         String(localized: "Moving")
        case .uninstall:    String(localized: "Uninstalling")
        case .launch:       String(localized: "Launching")
        }
    }
}

// MARK: - ProgressKVOBridge
@Observable final class ProgressKVOBridge: @unchecked Sendable {
    // swiftlint:disable:next identifier_name
    let _progress: Progress

    // Observables that mirror `Progress`
    private(set) var fractionCompleted: Double = 0.0
    private(set) var completedUnitCount: Int64 = 0
    private(set) var totalUnitCount: Int64 = 0
    private(set) var throughput: Int?
    private(set) var estimatedTimeRemaining: TimeInterval?
    private(set) var fileTotalCount: Int?
    private(set) var fileCompletedCount: Int?

    private var observers: Set<NSKeyValueObservation>
    private var lock: NSRecursiveLock = .init()
    private var pollingTimer: Timer?

    // register KVOs and send to observables
    init(progress: Progress) {
        self._progress = progress
        self.observers = .init()

        observers.insert(self._progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            Task { @MainActor in
                lock.withLock({ self.fractionCompleted = newValue })
            }
        })

        observers.insert(self._progress.observe(\.completedUnitCount, options: [.new]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            Task { @MainActor in
                lock.withLock({ self.completedUnitCount = newValue })
            }
        })

        observers.insert(self._progress.observe(\.totalUnitCount, options: [.new]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            Task { @MainActor in
                lock.withLock({ self.totalUnitCount = newValue })
            }
        })

        // polling task to update KVO-incompatible variables
        Task { @MainActor [weak self] in
            while let self = self {
                lock.withLock({ self.throughput = self._progress.throughput })
                lock.withLock({ self.estimatedTimeRemaining = self._progress.estimatedTimeRemaining })
                lock.withLock({ self.fileTotalCount = self._progress.fileTotalCount })
                lock.withLock({ self.fileCompletedCount = self._progress.fileCompletedCount })

                try await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    deinit { observers.forEach({ $0.invalidate() }) }
}
