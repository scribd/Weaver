//
//  InstanceCache.swift
//  BeaverDI
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Object responsible of caching instances.
/// The cache strategy is based on the `scope`.
protocol InstanceCaching {
    
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T
}

// MARK: - Implementation

final class InstanceCache: InstanceCaching {
    
    private var instances: [InstanceKey: InstanceBox] = [:]
    
    /// Caches an instance and returns it.
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {

        if scope.isTransient {
            return builder()
        }
        
        clearReleasedInstances()

        if let instance: T = get(for: key) {
            return instance
        }
        
        let instance = builder()
        let box = InstanceBox(instance as AnyObject, scope: scope)
        instances[key] = box
        return instance
    }
    
    private func get<T>(for key: InstanceKey) -> T? {
        return instances[key]?.instance as? T
    }
}

// MARK: - Clear

private extension InstanceCache {
    
    func clearReleasedInstances() {
        for key in instances.keys where instances[key]?.instance == nil {
            instances.removeValue(forKey: key)
        }
    }
}

// MARK: - InstanceBox

private extension InstanceCache {
    
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
