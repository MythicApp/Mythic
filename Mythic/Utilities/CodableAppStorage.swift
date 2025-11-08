//
//  SwiftUI+CodableAppStorage.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

/// A property wrapper that provides `@AppStorage`-like functionality for any `Codable` type.
///
/// This wrapper stores and retrieves `Codable` values from `UserDefaults`, using custom `.decodeAndGet` and `.encodeAndSet`.
/// SwiftUI views to automatically update when the stored value changes.
///
/// You can use this just like `@AppStorage`, including access to a `Binding` via `$`.
@propertyWrapper
struct CodableAppStorage<T>: DynamicProperty, Sendable where T: Codable & Sendable {
    @State private var value: T
    private let key: String

    public var wrappedValue: T {
        get { value }
        nonmutating set {
            value = newValue
            _ = try? defaults.encodeAndSet(newValue, forKey: key)
        }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { self.value },
            set: {
                self.value = $0
                _ = try? defaults.encodeAndSet($0, forKey: self.key)
            }
        )
    }

    public init(wrappedValue defaultValue: T, _ key: String, store defaults: UserDefaults = .standard) {
        self.key = key
        if let saved = try? defaults.decodeAndGet(T.self, forKey: key) {
            self._value = State(initialValue: saved)
        } else {
            self._value = State(initialValue: defaultValue)
            _ = try? defaults.encodeAndSet(defaultValue, forKey: key)
        }
    }
}
