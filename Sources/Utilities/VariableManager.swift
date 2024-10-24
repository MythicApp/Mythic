//
//  VariableManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/12/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

// MARK: - VariableManager Class
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
 
 Both
 ```
 if let hello: String = variableManager.getVariable("hello") {
    print(hello) // returns hi
 }
 ```
 */
@Observable class VariableManager: ObservableObject {
    static let shared = VariableManager()

    private var variables = [String: Any]()

    /// Set variable data within the variable manager.
    func setVariable(_ key: String, value: Any) {
        Task { @MainActor in
            self.objectWillChange.send()
            self.variables[key] = value
        }
    }

    /// Retrieve variable data from the variable manager.
    func getVariable<T>(_ key: String) -> T? {
        return variables[key] as? T
    }

    /// Remove variable data from the variable manager.
    func removeVariable(_ key: String) {
        Task { @MainActor in
            self.objectWillChange.send()
            self.variables[key] = nil
        }
    }
}
