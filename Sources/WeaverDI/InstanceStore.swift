//
//  InstanceStore.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Object responsible of caching instances.
/// The cache strategy is based on the `scope`.
protocol InstanceStoring {
    
    func set<T>(value: (instance: T, scope: Scope), for key: InstanceKey)
    
    func get<T>(for key: InstanceKey) -> T?
}

extension InstanceStoring {
    
    func set<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        
        guard !scope.isTransient else {
            return builder()
        }

        if let cachedInstance: T = get(for: key) {
            return cachedInstance
        }
        
        let instance = builder()
        set(value: (instance, scope), for: key)
        return instance
    }
}

// MARK: - Implementation

final class InstanceStore: InstanceStoring {
    
    private var instances: [InstanceKey: InstanceBox] = [:]
    
    func set<T>(value: (instance: T, scope: Scope), for key: InstanceKey) {
        clearReleasedInstances()
        let box = InstanceBox(value.instance as AnyObject, scope: value.scope)
        instances[key] = box
    }
    
    func get<T>(for key: InstanceKey) -> T? {
        guard let instance = instances[key]?.instance else {
            return nil
        }
        return instance as? T
    }
}

// MARK: - Clear

private extension InstanceStore {
    
    func clearReleasedInstances() {
        for key in instances.keys where instances[key]?.instance == nil {
            instances.removeValue(forKey: key)
        }
    }
}

// MARK: - InstanceBox

private extension InstanceStore {
    
    /// Object responsible of retaining weakly/strongly an instance.
    /// The retain strategy is based on the `scope`.
    final class InstanceBox {
        
        private weak var weakInstance: AnyObject?
        private var strongInstance: AnyObject?
        
        let scope: Scope
        
        init(_ instance: AnyObject, scope: Scope) {
            if scope.isWeak {
                weakInstance = instance
            } else {
                strongInstance = instance
            }
            self.scope = scope
        }
        
        var instance: AnyObject? {
            return weakInstance ?? strongInstance ?? nil
        }
    }
}
