//
//  EventManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 21/11/2023.
//

import Foundation

// A class that allows for cross-script variables and communication
// Example usage:
/*
 EventManager.shared.subscribe("test") { data in
     if let value = data as? String {
         print("chat is this \(value)")
        
     }
 }

 EventManager.shared.publish("test", "real?")
 */

/// Allows for cross-script communication via subscribeable events
class EventManager {
    /// The shared instance for events
    static let shared = EventManager()

    /// Event storage
    private var events = [String: [(Any) -> Void]]()

    /// Subscribe to events within the event manager
    /// - Parameter event: The event to subscribe to.
    public func subscribe(_ event: String, _ callback: @escaping (Any) -> Void) {
        if events[event] == nil {
            events[event] = Array()
        }
        events[event]?.append(callback)
    }
    
    /// Publish new values to events
    ///  -
    public func publish(_ event: String, _ data: Any) {
        if let callbacks = events[event] {
            for callback in callbacks {
                callback(data)
            }
        }
    }
}
