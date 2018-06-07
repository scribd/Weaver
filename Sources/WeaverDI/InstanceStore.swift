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
    
    func set<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T
}

// MARK: - Implementation

final class InstanceStore: InstanceStoring {
    
    private var instances: [InstanceKey: InstanceBox] = [:]
    
    func set<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {

        guard !scope.isTransient else {
            return builder()
        }

        clearReleasedInstances()
        
        if let cachedInstance = instances[key]?.instance as? T {
            return cachedInstance
        }
        
        let instance = builder()
        let instanceBox = InstanceBox(instance as AnyObject, scope: scope)
        instances[key] = instanceBox

        return instance
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
        
        init(_ instance: AnyObject, scope: Scope) {
            if scope.isWeak {
                weakInstance = instance
            } else {
                strongInstance = instance
            }
        }
        
        var instance: AnyObject? {
            return weakInstance ?? strongInstance ?? nil
        }
    }
}

// MARK: - SynchronizedInstanceStore

final class SynchronizedInstanceStore: InstanceStoring {
    
    private let instances: InstanceStoring
    
    private let lock = NSLock()
    
    init(_ instances: InstanceStoring) {
        self.instances = instances
    }
    
    func set<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return instances.set(for: key, scope: scope, builder: builder)
    }
}
