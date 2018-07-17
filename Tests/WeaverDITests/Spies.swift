//
//  Spies.swift
//  WeaverTests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

@testable import WeaverDI

final class BuilderStoreSpy: BuilderStoring {
 
    private(set) var getRecordsCallCount = 0
    
    private(set) var setRecordsCallCount = 0
    
    private(set) var keyRecords = [BuilderKey]()
        
    private(set) var isCalledFromAChildRecords = [Bool]()

    private(set) var builderRecords = [AnyBuilder]()
    
    var builderStubs = [BuilderKey: AnyBuilder]()
    
    var containsStubs = [BuilderKey: Bool]()
    
    weak var parent: BuilderStoring?

    func get<I, P>(for key: BuilderKey, isCalledFromAChild: Bool) -> Builder<I, P>? {
        keyRecords.append(key)
        isCalledFromAChildRecords.append(isCalledFromAChild)
        return builderStubs[key] as? Builder<I, P>
    }
    
    func set<I, P>(_ builder: Builder<I, P>, for key: BuilderKey) {
        builderRecords.append(builder)
        keyRecords.append(key)
        builderStubs[key] = builder
    }
    
    func contains(key: BuilderKey, isCalledFromAChild: Bool) -> Bool {
        keyRecords.append(key)
        isCalledFromAChildRecords.append(isCalledFromAChild)
        return containsStubs[key] ?? false
    }
}
