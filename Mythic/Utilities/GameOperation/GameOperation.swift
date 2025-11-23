//
//  GameOperation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

@Observable final class GameOperation: Operation, Identifiable, @unchecked Sendable {
    let id: UUID = .init()
    let game: Game
    let type: ActiveOperationType
    private(set) var progress: Progress
    let function: (Progress) async throws -> Void

    var error: Error?

    init(game: Game,
         type: ActiveOperationType,
         progress: Progress = .init(),
         function: @escaping (Progress) async throws -> Void) {
        self.game = game
        self.type = type
        self.progress = progress
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
                try await function(progress)
            } catch {
                self.error = error
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
