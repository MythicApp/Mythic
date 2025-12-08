//
//  StagedFlow.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

@MainActor protocol StagedFlow: AnyObject {
    associatedtype Stage: CaseIterable & Equatable
    
    var stages: [Stage] { get }
    var currentStage: Stage { get set }
}

extension StagedFlow {
    var fractionCompleted: Double {
        precondition(!stages.isEmpty, "Stages cannot be empty in a StagedFlow viewmodel.")
        return .init((stages.firstIndex(of: currentStage) ?? 0) + 1 / stages.count)
    }
    
    /**
     Steps stage by delta value.
     - Parameters:
     - by: The integer to step the current stage by.
     */
    func stepStage(by delta: Int = 1, animation: Animation? = .bouncy) {
        let newIndex = (stages.firstIndex(of: currentStage) ?? 0) + delta
        precondition(stages.indices.contains(newIndex), """
            Unable to step to index \(newIndex) from \(newIndex - delta), since the new index is out of bounds.
            This is unintended behaviour.
            """)
        
        withAnimation(animation) {
            currentStage = stages[newIndex]
        }
    }

    func reset(animation: Animation? = .bouncy) {
        precondition(!stages.isEmpty, "Stages cannot be empty in a StagedFlow viewmodel.")
        
        withAnimation(animation) {
            currentStage = stages.first!
        }
    }
}
