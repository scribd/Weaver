//
//  OrderedDictionary.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/15/18.
//

import Foundation

// MARK: - Dictionary

final class OrderedDictionary<Key: Hashable, Value> {
    
    private(set) var dictionary = [Key: Value]()
    
    private(set) var orderedKeys = [Key]()
    
    struct KeyValue {
        let key: Key
        let value: Value
    }
    
    var orderedKeyValues: [KeyValue] {
        var result = [KeyValue]()
        for key in orderedKeys {
            dictionary[key].flatMap { result.append(KeyValue(key: key, value: $0)) }
        }
        return result
    }

    var orderedValues: [Value] {
        return orderedKeyValues.map { $0.value }
    }
    
    subscript(key: Key) -> Value? {
        get {
            return dictionary[key]
        }
        set {
            if dictionary[key] == nil {
                orderedKeys.append(key)
            } else {
                orderedKeys.index(of: key).flatMap { index -> Void in
                    orderedKeys.remove(at: index)
                }
                orderedKeys.append(key)
            }
            dictionary[key] = newValue
        }
    }
}
