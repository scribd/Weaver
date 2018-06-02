//
//  ThreadSafeInstanceCachingDecorator.swift
//  WeaverDI
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

final class ThreadSafeInstanceCacheDecorator: InstanceCaching {
    
    private let instances: InstanceCaching
    private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    init(instances: InstanceCaching) {
        self.instances = instances
    }
    
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        self.semaphore.wait()
        defer {
            self.semaphore.signal()
        }
        
        return self.instances.cache(for: key, scope: scope, builder: builder)
    }
}
