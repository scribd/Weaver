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
    
    private(set) var scopeRecords = [Scope]()
    
    private(set) var isCalledFromAChildRecords = [Bool]()

    private(set) var builderRecords = [Any]()
    
    var builderStubs = [BuilderKey: Builder]()
    
    weak var parent: BuilderStoring?

    func get(for key: BuilderKey, isCalledFromAChild: Bool) -> Builder? {
        keyRecords.append(key)
        isCalledFromAChildRecords.append(isCalledFromAChild)
        return builderStubs[key]
    }
    
    func set<P, I>(scope: Scope, key: BuilderKey, builder: @escaping (() -> P) -> I) {
        builderRecords.append(builder as Any)
        scopeRecords.append(scope)
        keyRecords.append(key)
        builderStubs[key] = Builder(scope: scope, body: builder)
    }
}
