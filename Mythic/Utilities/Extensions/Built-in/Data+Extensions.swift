//
//  Data.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/10/2023.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import CryptoKit

extension Data {
    /// Generates the data's SHA-256 hash.
    var hash: Data {
        return Data(SHA256.hash(data: self))
    }
}
