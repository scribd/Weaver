//
//  InstanceCacheTests.swift
//  BeaverDITests
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation
import XCTest

@testable import BeaverDI

final class InstanceCacheSpecs: XCTestCase {
    
    var instances: InstanceCache!
    let instanceKey = InstanceKey(for: InstanceStub.self)
    
    override func setUp() {
        super.setUp()
        
        instances = InstanceCache()
    }
    
    // When scope is `weak`.
    
    func testCacheShouldReleaseWeakReferencesWhenItsNotBeingHoldAnymore() {
        
        var instanceStub: InstanceStub? = InstanceStub()
        weak var weakInstanceStub: InstanceStub? = instanceStub
        
        _ = instances.cache(for: instanceKey, scope: .weak) { instanceStub }
        
        instanceStub = nil
        
        XCTAssertNil(weakInstanceStub)
    }
    
    func testCacheShouldBuildTheInstanceOnlyIfThePreviousInstanceHasBeenReleased() {
        
        let firstInstance = instances.cache(for: instanceKey, scope: .weak) { InstanceStub() }
        let secondInstance = instances.cache(for: instanceKey, scope: .weak) { InstanceStub() }

        XCTAssertEqual(firstInstance, secondInstance)
    }
    
    // When scope is `transient`.

    func testCacheShouldCreateANewReferenceWhenScopeIsTransient() {
        
        let firstInstance = instances.cache(for: instanceKey, scope: .transient) { InstanceStub() }
        let secondInstance = instances.cache(for: instanceKey, scope: .transient) { InstanceStub() }

        XCTAssertNotEqual(firstInstance, secondInstance)
    }
    
    func testCacheShouldNotHoldTheReferenceWhenScopeIsTransient() {

        var instanceStub: InstanceStub? = InstanceStub()
        weak var weakInstanceStub: InstanceStub? = instanceStub
        
        _ = instances.cache(for: instanceKey, scope: .transient) { instanceStub }
        
        instanceStub = nil
        
        XCTAssertNil(weakInstanceStub)
    }
    
    // When scope is `graph`.
    
    func testCacheShouldBuildTheInstanceOnlyOnceWhenScopeIsGraph() {

        let firstInstance = instances.cache(for: instanceKey, scope: .graph) { InstanceStub() }
        let secondInstance = instances.cache(for: instanceKey, scope: .graph) { InstanceStub() }
        
        XCTAssertEqual(firstInstance, secondInstance)
    }
}

private extension InstanceCacheSpecs {
    
    final class InstanceStub: Equatable {
        static func ==(lhs: InstanceCacheSpecs.InstanceStub, rhs: InstanceCacheSpecs.InstanceStub) -> Bool {
            return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }
    }
}
