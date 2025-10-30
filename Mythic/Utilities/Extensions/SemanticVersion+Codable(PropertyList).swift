//
//  SemanticVersion+Codable(PropertyList).swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SemanticVersion

// reimplementation of SemanticVersion+Codable for plists
public extension PropertyListDecoder {
    var semanticVersionDecodingStrategy: SemanticVersionStrategy {
        get { userInfo.semanticDecodingStrategy }
        set { userInfo.semanticDecodingStrategy = newValue }
    }
}

public extension PropertyListEncoder {
    var semanticVersionEncodingStrategy: SemanticVersionStrategy {
        get { userInfo.semanticDecodingStrategy }
        set { userInfo.semanticDecodingStrategy = newValue }
    }
}

private extension Dictionary where Key == CodingUserInfoKey, Value == Any {
    var semanticDecodingStrategy: SemanticVersionStrategy {
        get { (self[.semanticVersionStrategy] as? SemanticVersionStrategy) ?? .defaultCodable }
        set { self[.semanticVersionStrategy] = newValue }
    }
}

private extension CodingUserInfoKey {
    static let semanticVersionStrategy = Self(rawValue: "SemanticVersionEncodingStrategy")!
}
