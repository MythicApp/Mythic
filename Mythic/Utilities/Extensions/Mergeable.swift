//
//  Mergeable.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 23/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

protocol Mergeable {
    mutating func merge(_ other: Self)
}
