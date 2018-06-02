//
//  ThreadSafeInstanceCachingDecorator.swift
//  WeaverDI
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

final class ThreadSafeInstanceCacheDecorator: InstanceCaching {
    
    private let instances: InstanceCaching
    private let queue = DispatchQueue(label: "\(ThreadSafeInstanceCacheDecorator.self)")
    
    init(instances: InstanceCaching) {
        self.instances = instances
    }
    
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        var entry: T?
        
        queue.sync {
            entry = self.instances.cache(for: key, scope: scope, builder: builder)
        }
        
        assert(entry != nil, "Entry can't theoritically be nil.")
        return entry ?? builder()
    }
}
