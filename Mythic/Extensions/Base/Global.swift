//
//  Global.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/2023.
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

 EventManager.shared.publish("test", "real")
 */

class EventManager {
    static let shared = EventManager()

    var events = [String: [(Any) -> Void]]()

    func subscribe(_ event: String, _ callback: @escaping (Any) -> Void) {
        if events[event] == nil {
            events[event] = Array()
        }
        events[event]?.append(callback)
    }

    func publish(_ event: String, _ data: Any) {
        if let callbacks = events[event] {
            for callback in callbacks {
                callback(data)
            }
        }
    }
}

func isAppInstalled(bundleIdentifier: String) -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = [
        "bash", "-c",
        "mdfind \"kMDItemCFBundleIdentifier == '\(bundleIdentifier)'\""
    ]

    let stdout = Pipe()
    process.standardOutput = stdout
    process.launch()

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String()

    return !output.isEmpty
}
