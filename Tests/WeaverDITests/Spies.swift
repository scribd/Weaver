//
//  Spies.swift
//  WeaverTests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

@testable import WeaverDI

final class InstanceStoreSpy: InstanceStoring {

    private(set) var keyRecords = [InstanceKey]()
    
    private(set) var scopeRecords = [Scope]()
    
    func set<T>(for key: InstanceKey, scope: Scope, builder: () -> T) -> T {
        keyRecords.append(key)
        scopeRecords.append(scope)
        return builder()
    }
}

final class BuilderStoreSpy: BuilderStoring {

    private(set) var getRecordsCallCount = 0
    
    private(set) var setRecordsCallCount = 0
    
    private(set) var keyRecords = [InstanceKey]()
    
    private(set) var scopeRecords = [Scope]()

    private(set) var builderRecords = [Any]()
    
    var builderStubs = [InstanceKey:Any]()
    
    weak var parent: BuilderStoring?

    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B? {
        keyRecords.append(key)
        return builderStubs[key] as? B
    }
    
    func set<B>(builder: B, scope: Scope, for key: InstanceKey) {
        builderRecords.append(builder as Any)
        scopeRecords.append(scope)
        keyRecords.append(key)
        builderStubs[key] = builder
    }
}
