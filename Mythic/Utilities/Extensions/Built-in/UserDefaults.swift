//
//  UserDefaults.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 26/5/2024.
//

// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
