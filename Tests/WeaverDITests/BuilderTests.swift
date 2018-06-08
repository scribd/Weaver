//
//  BuilderTests.swift
//  WeaverDITests
//
//  Created by Théophane Rupin on 6/7/18.
//

import Foundation
import XCTest

@testable import WeaverDI

final class BuilderTests: XCTestCase {

    func test_builder_should_create_a_weak_instance_when_scope_is_weak() {
        
        let builder = Builder(scope: .weak, body: { (_: () -> Void) -> NSObject in return NSObject() })
        let functor: (() -> Void) -> NSObject = builder.functor()
        
        var strongInstance: NSObject? = functor({()})
        weak var weakInstance: NSObject? = functor({()})
        
        XCTAssertEqual(strongInstance, weakInstance)
        strongInstance = nil
        XCTAssertNil(weakInstance)
    }
    
    func test_builder_should_create_a_strong_instance_when_scope_is_container() {
        
        let builder = Builder(scope: .container, body: { (_: () -> Void) -> NSObject in return NSObject() })
        let functor: (() -> Void) -> NSObject = builder.functor()
        
        var strongInstance: NSObject? = functor({()})
        weak var weakInstance: NSObject? = functor({()})
        
        XCTAssertEqual(strongInstance, weakInstance)
        strongInstance = nil
        XCTAssertNotNil(weakInstance)
    }
    
    func test_builder_should_create_a_strong_instance_when_scope_is_graph() {
        
        let builder = Builder(scope: .graph, body: { (_: () -> Void) -> NSObject in return NSObject() })
        let functor: (() -> Void) -> NSObject = builder.functor()
        
        var strongInstance: NSObject? = functor({()})
        weak var weakInstance: NSObject? = functor({()})
        
        XCTAssertEqual(strongInstance, weakInstance)
        strongInstance = nil
        XCTAssertNotNil(weakInstance)
    }

    func test_builder_should_create_new_instances_when_scope_is_transient() {
        
        let builder = Builder(scope: .transient, body: { (_: () -> Void) -> NSObject in return NSObject() })
        let functor: (() -> Void) -> NSObject = builder.functor()
        
        var strongInstance: NSObject? = functor({()})
        weak var weakInstance: NSObject? = functor({()})
        
        XCTAssertNotEqual(strongInstance, weakInstance)
        strongInstance = nil
        XCTAssertNil(weakInstance)
    }
    
    // The race condition being extremely unlikely, this test would need to run for at least one
    // minute in order to "prove" the builder thread-safety.
    // This is why the test is deactivated, but kept here since it can be handy to debug concurrency.
    func xtest_builder_should_ensure_thread_safety_when_building_concurrently() {

        var instances = Set<NSObject>()
        let lock = NSLock()
        
        let dispatchQueue = DispatchQueue(label: "\(DependencyContainerTests.self)", attributes: [.concurrent])

        let expectations = (1...10000).flatMap { stepIndex -> [XCTestExpectation] in
            let builder = Builder(scope: .container, body: { (_: () -> Void) -> NSObject in return NSObject() })
            
            return (1...100).map { threadIndex -> XCTestExpectation in
                let expectation = self.expectation(description: "concurrent_resolution_\(stepIndex)_\(threadIndex)")
                dispatchQueue.async {
                    let functor: (() -> Void) -> NSObject = builder.functor()
                    let instance = functor({()})
                    
                    lock.lock()
                    instances.insert(instance)
                    lock.unlock()
                    expectation.fulfill()
                }
                return expectation
            }
        }
        
        wait(for: expectations, timeout: 10)
        
        XCTAssertEqual(instances.count, 10000)
    }
}
