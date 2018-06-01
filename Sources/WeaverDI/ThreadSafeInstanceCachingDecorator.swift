//
//  ThreadSafeInstanceCachingDecorator.swift
//  WeaverDI
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

class ThreadSafeInstanceCachingDecorator: InstanceCaching {
    
    let cache: InstanceCaching
    let semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    init(cache: InstanceCaching) {
        self.cache = cache
    }
    
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        self.semaphore.wait()
        defer {
            self.semaphore.signal()
        }
        
        return self.cache.cache(for: key, scope: scope, builder: builder)
    }
}
