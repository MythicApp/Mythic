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
    func encodeAndSet<T: Encodable>(_ data: T, forKey key: String) throws -> Data {
        let encodedData = try PropertyListEncoder().encode(data)
        set(encodedData, forKey: key)
        return encodedData
    }
    
    @discardableResult
    func encodeAndRegister(defaults registrationDictionary: [String: Encodable]) throws -> [String: Any] {
        for (key, value) in registrationDictionary {
            let encodedData = try PropertyListEncoder().encode(value)
            register(defaults: [key: encodedData])
        }
        
        return dictionaryRepresentation()
    }
    
    func decodeAndGet<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = data(forKey: key) else { return nil }
        let decodedData = try PropertyListDecoder().decode(T.self, from: data)
        return decodedData
    }
}
