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

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

// MARK: - EventManager Class
/**
 A class that allows for cross-script variables and communication.
 
 Example usage:
 ```
 let subscription1 = EventManager.shared.subscribe("test") { data in
     if let value = data as? String {
         print("Subscription 1: chat is this '\(value)'")
     }
 }

 // Another subscription to "test"
 let subscription2 = EventManager.shared.subscribe("test") { data in
     if let value = data as? String {
         print("Subscription 2: chat is this '\(value)'")
     }
 }
 
 EventManager.shared.publish("test", "real?")
 
 EventManager.shared.unsubscribe("test", id: subscription1) // remotely stop callback 1 from getting any more updates
 
 EventManager.shared.wipe("test") // womp womp, callback 2 should now be nil
 ```
 */
class EventManager {
    /// The shared instance for events.
    static let shared = EventManager()
    
    /// Event storage.
    private var events = [String: [UUID: (Any) -> Void]]()
    
    /// DispatchQueue for event management, promotes thread safety
    private let queue = DispatchQueue(label: "EventManager", attributes: .concurrent)
    
    // MARK: - Subscribe Method
    /**
     Subscribe to events within the event manager.
     
     - Parameters:
        - event: The name of the event to subscribe to.
        - callback: The closure to be called when the event is triggered.
     
     - Returns: The UUID of the subscription created.
     */
    @discardableResult
    public func subscribe(_ event: String, _ callback: @escaping (Any) -> Void) -> UUID {
        let id: UUID! = .init()
        
        queue.sync(flags: .barrier) {
            self.events[event] = self.events[event] ?? [:]
            self.events[event]?[id] = callback
        }
        
        return id
    }
    
    // MARK: - Unsubscrbe Method
    /**
     Removes all subscribed callbacks for a specified event.

     - Parameters:
        - event: The name of the event from which to unsubscribe.
        - id: The ID of the closure that will unsubscribe.
     */
    public func unsubscribe(_ event: String, id: UUID) {
        queue.async(flags: .barrier) {
            self.events[event]?[id] = nil
        }
    }
    
    // MARK: - Unsubscribe All Method
    /**
     Removes all callbacks and data of a specific event

     - Parameter event: The name of the event from which to unsubscribe.
     */
    public func unsubscribeAll(_ event: String) {
        queue.async(flags: .barrier) {
            self.events[event]?.removeAll()
        }
    }
    
    // MARK: - Wipe Method
    /**
     Removes callbacks and data of a specific event.

     - Parameter event: The name of the event from which to wipe.
     */
    public func wipe(_ event: String) {
        queue.async(flags: .barrier) { // .barrier protects other tasks concurrently running, avoids data races
            self.events[event] = nil
        }
    }
    
    // MARK: - Publish Method
    /**
     Publish new values to events.
     
     - Parameters:
        - event: The event to publish to.
        - data: The data to publish to the event.
     */
    public func publish(_ event: String, _ data: Any) {
        queue.sync {
            if let callbacks = self.events[event] {
                for callback in callbacks.values {
                    callback(data)
                }
            }
        }
    }
}
