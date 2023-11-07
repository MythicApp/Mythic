//
//  Data.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/10/2023.
//

import Foundation
import CryptoKit

extension Data {
    /// Generates the data's SHA-256 hash.
    var hash: Data {
        return Data(SHA256.hash(data: self))
    }
}
