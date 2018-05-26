//
//  InstanceCacheMock.swift
//  WeaverTests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

@testable import WeaverDI

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

final class BuilderStoreMock: BuilderStoring {

    private(set) var getCallCount = 0
    
    private(set) var setCallCount = 0
    
    private(set) var key: InstanceKey?
    
    private(set) var scope: Scope?

    private(set) var builder: Any?
    
    weak var parent: BuilderStoring?

    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B? {
        self.key = key
        getCallCount += 1
        return builder as? B
    }
    
    func set<B>(builder: B, scope: Scope, for key: InstanceKey) {
        self.builder = builder
        self.scope = scope
        self.key = key
        setCallCount += 1
    }
}
