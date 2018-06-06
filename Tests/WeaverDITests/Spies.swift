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
    
    private(set) var instanceRecords = [Any]()
    
    var instanceStubs = [InstanceKey: AnyObject]()
    
    func set<T>(value: (instance: T, scope: Scope), for key: InstanceKey) {
        keyRecords.append(key)
        scopeRecords.append(value.scope)
        instanceRecords.append(value.instance)
        instanceStubs[key] = value.instance as AnyObject
    }
    
    func get<T>(for key: InstanceKey) -> T? {
        keyRecords.append(key)
        return instanceStubs[key] as? T
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
