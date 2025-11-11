//
//  UserDefaults.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 26/5/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension UserDefaults {
    @discardableResult
    func encodeAndSet<T>(_ data: T, forKey key: String) throws -> Data where T: Encodable {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let mirror: Mirror = .init(reflecting: data)

        // PropertyListCoders require an array at the top level or it doesn't follow plist conventions.
        // If the data is not an array or dictionary, wrap it in an array.
        let encodedData: Data
        switch mirror.displayStyle {
        case .collection, .dictionary:
            encodedData = try encoder.encode(data)
        default:
            encodedData = try encoder.encode([data])
        }

        set(encodedData, forKey: key)
        return encodedData
    }

    @discardableResult
    func encodeAndRegister(defaults registrationDictionary: [String: Encodable]) throws -> [String: Any] {
        for (key, value) in registrationDictionary {
            try encodeAndSet(value, forKey: key)
        }
        
        return dictionaryRepresentation()
    }
    
    func decodeAndGet<T>(_ type: T.Type, forKey key: String) throws -> T? where T: Decodable {
        guard let data = data(forKey: key) else { return nil }
        let decoder: PropertyListDecoder = .init()

        // Attempt to decode value using the direct value of T
        if let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }

        // PropertyListCoders require an array at the top level or it doesn't follow plist conventions.
        // Thus, if the data is not an array or dictionary, it was likely wrapped in an array before being encoded.
        if let decodedArray = try? decoder.decode([T].self, from: data) {
            return decodedArray.first
        }
        
        return nil
    }
}
