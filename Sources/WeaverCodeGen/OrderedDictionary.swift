//
//  OrderedDictionary.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/15/18.
//

import Foundation

// MARK: - Dictionary

final class OrderedDictionary<Key, Value> where Key: Hashable {
    
    private(set) var dictionary = [Key: Value]()
    
    private(set) var orderedKeys = [Key]()
    
    struct KeyValue {
        let key: Key
        let value: Value
    }
    
    init(_ keyValues: [(Key, Value)] = []) {
        keyValues.reversed().forEach { key, value in
            guard dictionary[key] == nil else { return }
            dictionary[key] = value
            orderedKeys = [key] + orderedKeys
        }
    }
    
    var orderedKeyValues: [KeyValue] {
        return orderedKeys.compactMap { key in
            guard let value = dictionary[key] else { return nil }
            return KeyValue(key: key, value: value)
        }
    }

    var orderedValues: [Value] {
        return orderedKeyValues.map { $0.value }
    }
    
    subscript(key: Key) -> Value? {
        get {
            return dictionary[key]
        }
        set {
            if dictionary[key] == nil && newValue != nil {
                orderedKeys.append(key)
            } else {
                orderedKeys.firstIndex(of: key).flatMap { index -> Void in
                    orderedKeys.remove(at: index)
                }
                if newValue != nil {
                    orderedKeys.append(key)
                }
            }
            dictionary[key] = newValue
        }
    }
    
    var isEmpty: Bool {
        return dictionary.isEmpty
    }
}

extension OrderedDictionary: Encodable where Key: Encodable, Value: Encodable {}
