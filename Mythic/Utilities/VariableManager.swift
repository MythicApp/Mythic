//
//  VariableManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/12/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

/**
 A flexible class that enables cross-script variables.
 
 Example usage:
 
 SwiftUI
 ```
 @ObservedObject private var variables: VariableManager = .shared
 variableManager.setVariable("hello", value: "hi")
 ```
 
 Swift
 ```
 let variableManager: VariableManager = .shared
 variableManager.setVariable("hello", value: "hi")
 ```
 */
@MainActor
@Observable class VariableManager: ObservableObject, @unchecked Sendable {
    static let shared: VariableManager = .init()
    private init() { }
    
    private var variables = [String: Any]()
    
    /// Set variable data within the variable manager.
    func setVariable(_ key: String, value: Any) {
        self.objectWillChange.send()
        self.variables[key] = value
    }
    
    /// Retrieve variable data from the variable manager.
    func getVariable<T>(_ key: String) -> T? {
        return variables[key] as? T
    }
    
    /// Remove variable data from the variable manager.
    func removeVariable(_ key: String) {
        self.objectWillChange.send()
        self.variables[key] = nil
    }
}
