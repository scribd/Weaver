//
//  InstanceCacheMock.swift
//  BeaverDITests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

@testable import BeaverDI

final class InstanceCacheMock: InstanceCaching {

    private(set) var cacheCallCount = 0
    
    private(set) var key: InstanceKey?
    
    private(set) var scope: Scope?
    
    func cache<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        self.key = key
        self.scope = scope
        cacheCallCount += 1
        return builder()
    }
}
