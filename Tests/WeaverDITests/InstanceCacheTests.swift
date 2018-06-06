//
//  InstanceCacheTests.swift
//  WeaverTests
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation
import XCTest

@testable import WeaverDI

final class InstanceCacheSpecs: XCTestCase {
    
    var instances: InstanceStore!
    let instanceKey = InstanceKey(for: InstanceStub.self, name: "test")
    
    override func setUp() {
        super.setUp()
        
        instances = InstanceStore()
    }
    
    override func tearDown() {
        defer { super.tearDown() }
        
        instances = nil
    }
    
    // When scope is `weak`.
    
    func test_set_should_release_weak_references_when_its_not_being_hold_anymore() {
        
        var instanceStub: InstanceStub? = InstanceStub()
        weak var weakInstanceStub: InstanceStub? = instanceStub
        
        _ = instances.set(for: instanceKey, scope: .weak) { instanceStub }
        
        instanceStub = nil
        
        XCTAssertNil(weakInstanceStub)
    }
    
    func test_set_should_build_the_instance_only_if_the_previous_instance_has_been_released() {
        
        let firstInstance = instances.set(for: instanceKey, scope: .weak) { InstanceStub() }
        let secondInstance = instances.set(for: instanceKey, scope: .weak) { InstanceStub() }

        XCTAssertEqual(firstInstance, secondInstance)
    }
    
    // When scope is `transient`.

    func test_set_should_create_a_new_reference_when_scope_is_transient() {
        
        let firstInstance = instances.set(for: instanceKey, scope: .transient) { InstanceStub() }
        let secondInstance = instances.set(for: instanceKey, scope: .transient) { InstanceStub() }

        XCTAssertNotEqual(firstInstance, secondInstance)
    }
    
    func test_set_should_not_hold_the_reference_when_scope_is_transient() {

        var instanceStub: InstanceStub? = InstanceStub()
        weak var weakInstanceStub: InstanceStub? = instanceStub
        
        _ = instances.set(for: instanceKey, scope: .transient) { instanceStub }
        
        instanceStub = nil
        
        XCTAssertNil(weakInstanceStub)
    }
    
    // When scope is `graph`.
    
    func test_set_should_build_the_instance_only_once_when_scope_is_graph() {

        let firstInstance = instances.set(for: instanceKey, scope: .graph) { InstanceStub() }
        let secondInstance = instances.set(for: instanceKey, scope: .graph) { InstanceStub() }
        
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
