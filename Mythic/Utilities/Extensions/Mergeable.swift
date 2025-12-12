//
//  Mergeable.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 23/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

protocol Mergeable: AnyObject {
    associatedtype MergeKeys: CodingKey & CaseIterable & Hashable
    
    /// Properties that are intentionally not merged (e.g., id, immutable fields).
    static var ignoredMergeKeys: Set<MergeKeys> { get }
    
    /// Define merge rules for each property.
    var mergeRules: [AnyMergeRule] { get }
}

extension Mergeable {
    /// Merges properties from `other` into `self`, using the merge rules of `self`.
    func merge(with other: Self) {
        let context: MergeContext<MergeKeys, Self> = .init(target: self, source: other)
        context.apply(mergeRules)
    }
}

/// Type-erased merge rule.
struct AnyMergeRule {
    fileprivate let codingKey: AnyHashable
    private let applyRule: (AnyObject, AnyObject) -> Void
    
    init<Target, Value>(
        _ keyPath: ReferenceWritableKeyPath<Target, Value>,
        forCodingKey key: Target.MergeKeys,
        strategy: @escaping (Value, Value) -> Value
    ) where Target: Mergeable {
        self.codingKey = AnyHashable(key)
        self.applyRule = { target, source in
            guard let typedTarget: Target = target as? Target,
                  let typedSource: Target = source as? Target else {
                return
            }
            
            let targetValue: Value = typedTarget[keyPath: keyPath]
            let sourceValue: Value = typedSource[keyPath: keyPath]
            typedTarget[keyPath: keyPath] = strategy(targetValue, sourceValue)
        }
    }
    
    func apply<Target>(target: Target, source: Target) where Target: AnyObject {
        applyRule(target, source)
    }
}

/// Context for tracking which keys have been merged.
final class MergeContext<Key, Target> where Key: CodingKey & CaseIterable & Hashable, Target: Mergeable, Target.MergeKeys == Key {
    private var mergedKeys: Set<Key> = .init()
    private let expectedKeys: Set<Key>
    private let ignoredKeys: Set<Key>
    
    private let target: Target
    private let source: Target
    
    /**
     Initializes a merge context for combining a source object into a target object.
     
     - Parameters:
        - target: The object that will be modified by merging.
        - source: The object whose properties will be merged into the target.
     */
    init(target: Target, source: Target) {
        self.ignoredKeys = Target.ignoredMergeKeys
        self.expectedKeys = Set(Key.allCases).subtracting(ignoredKeys)
        self.target = target
        self.source = source
    }
    
    deinit {
        let unmergedKeys: Set<Key> = expectedKeys.subtracting(mergedKeys)
        
        assert(unmergedKeys.isEmpty, """
            Merge validation failed for \(String(describing: Target.self)):
            Unmerged keys: \(unmergedKeys.map(\.stringValue).sorted().formatted(.list(type: .and)))
            
            All non-ignored keys must be merged using mergeProperty/mergeOptional.
            Either merge them or add to ignoredMergeKeys.
            
            Expected to merge: \(expectedKeys.map(\.stringValue).sorted().formatted(.list(type: .and)))
            Actually merged: \(mergedKeys.map(\.stringValue).sorted().formatted(.list(type: .and)))
            Ignored: \(ignoredKeys.map(\.stringValue).sorted().formatted(.list(type: .and)))
            """)
    }
    
    /// Applies merge rules to combine source properties into target.
    func apply(_ rules: [AnyMergeRule]) {
        for rule in rules {
            guard let key = rule.codingKey.base as? Key else { continue }
            
            rule.apply(target: target, source: source)
            mergedKeys.insert(key)
        }
    }
}
