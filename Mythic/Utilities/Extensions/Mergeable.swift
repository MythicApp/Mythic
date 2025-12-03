//
//  Mergeable.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 23/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

protocol Mergeable {
    /// Properties that are intentionally not merged (e.g., id, immutable fields).
    static var ignoredMergeKeys: Set<String> { get }
    
    /// Merge a **source-of-truth** `Mergeable` object with another object.
    @discardableResult mutating func merge(with other: Self) -> MergeContext
}

/// Context for tracking which keys have been merged.
final class MergeContext {
    private(set) var mergedKeys: Set<String> = []
    private var isValidated: Bool = false
    
    func markKeyAsMerged(_ key: String) { mergedKeys.insert(key) }
    
    fileprivate func markValidated() { isValidated = true }
    
    deinit {
        if !isValidated {
            assertionFailure("""
                You must call validateMergeCompleteness() at the end of your merge implementation.
                """)
        }
    }
}

extension Mergeable where Self: Codable {
    /// Helper to merge a property and track it using CodingKey.
    mutating func mergeProperty<Value, Key>(
        _ key: Key,
        _ keyPath: WritableKeyPath<Self, Value>,
        from other: Self,
        context: inout MergeContext,
        using strategy: (inout Value, Value) -> Void
    ) where Key: CodingKey {
        var current = self[keyPath: keyPath]
        let incoming = other[keyPath: keyPath]
        
        strategy(&current, incoming)
        
        self[keyPath: keyPath] = current
        context.markKeyAsMerged(key.stringValue)
    }
    
    /// Helper for optional properties (nil-coalescence merge).
    mutating func mergeOptional<Value, Key>(
        _ key: Key,
        _ keyPath: WritableKeyPath<Self, Value?>,
        from other: Self,
        context: inout MergeContext
    ) where Key: CodingKey {
        mergeProperty(key, keyPath, from: other, context: &context) { current, incoming in
            current = current ?? incoming
        }
    }
    
    /// Validates that all CodingKeys are either merged or explicitly ignored.
    /// Call this at the end of your merge implementation.
    func validateMergeCompleteness<T>(
        codingKeys: T.Type,
        context: MergeContext
    ) where T: CodingKey & CaseIterable {
        let allKeys: Set<String> = .init(codingKeys.allCases.map { $0.stringValue })
        let expectedKeysForMerge: Set<String> = allKeys.subtracting(Self.ignoredMergeKeys)
        
        let unmergedKeys: Set<String> = expectedKeysForMerge.subtracting(context.mergedKeys)
        
        context.markValidated()
        
        assert(unmergedKeys.isEmpty, """
            Merge validation failed for \(Self.self):
            Unmerged keys: \(unmergedKeys.sorted().formatted(.list(type: .and)))
            
            All non-ignored keys must be merged using mergeProperty/mergeOptional.
            Either merge them or add to ignoredKeys.
            
            Expected to merge: \(expectedKeysForMerge.sorted().formatted(.list(type: .and)))
            Actually merged: \(context.mergedKeys.sorted().formatted(.list(type: .and)))
            Ignored: \(Self.ignoredMergeKeys.sorted().formatted(.list(type: .and)))
            """)
    }
}
