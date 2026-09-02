//
//  Data.swift
//  Mythic
//
//  Created by zenfty on 25/10/2023.
//

// Copyright © 2023-2026 zenfty

import Foundation
import CryptoKit

extension Data {
    /// Generates the data's SHA-256 hash.
    var hash: Data {
        return Data(SHA256.hash(data: self))
    }
}
