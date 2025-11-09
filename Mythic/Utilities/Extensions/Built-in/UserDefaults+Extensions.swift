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
        let encoder: PropertyListEncoder = .init()
        encoder.outputFormat = .binary

        let encodedData = try encoder.encode([data])
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

        // FIXME: older versions of Mythic would decode data that was NOT wrapped in an array.
        // PropertyListCoders require an array at the top level or it doesn't follow plist conventions.
        // ‼️ This code should be removed before v1.0.0, along with Migrator.
        if let decodedData = try? PropertyListDecoder().decode(T.self, from: data) {
            return decodedData
        }

        let decodedData = try PropertyListDecoder().decode([T].self, from: data)
        return decodedData.first
    }
}
