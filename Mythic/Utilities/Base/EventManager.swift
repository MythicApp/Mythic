//
//  EventManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 21/11/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎]

import Foundation

// MARK: - EventManager Class
/**
 A class that allows for cross-script variables and communication.
 
 Example usage:
 ```
 EventManager.shared.subscribe("test") { data in
    if let value = data as? String {
        print("chat is this (value)")
    }
 }
 
 EventManager.shared.publish("test", "real?")
 ```
 */
class EventManager {
    /// The shared instance for events.
    static let shared = EventManager()
    
    /// Event storage.
    private var events = [String: [(Any) -> Void]]()
    
    // MARK: - Subscribe Method
    /** Subscribe to events within the event manager.
     
     - Parameter event: The name of the event to subscribe to.
     - Parameter callback: The closure to be called when the event is triggered.
     */
    public func subscribe(_ event: String, _ callback: @escaping (Any) -> Void) {
        if events[event] == nil {
            events[event] = Array()
        }
        events[event]?.append(callback)
    }
    
    // MARK: - Publish Method
    /** Publish new values to events.
     
     - Parameters:
     - event: The event to publish to.
     - data: The data to publish to the event.
     */
    public func publish(_ event: String, _ data: Any) {
        if let callbacks = events[event] {
            for callback in callbacks {
                callback(data)
            }
        }
    }
}
