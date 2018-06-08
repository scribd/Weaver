////
////  BuilderStoreTests.swift
////  WeaverTests
////
////  Created by Théophane Rupin on 2/21/18.
////
//
//import Foundation
//import XCTest
//
//@testable import WeaverDI
//
//final class BuilderStoreTests: XCTestCase {
//
//    var rootBuilderStore: BuilderStore!
//    var parentBuilderStore: BuilderStore!
//    var childBuilderStore: BuilderStore!
//    
//    let instanceKey = InstanceKey(for: String.self, name: "test")
//    
//    func rootBuilder() -> String {
//        return "root_builder"
//    }
//    
//    func parentBuilder() -> String {
//        return "parent_builder"
//    }
//    
//    func childBuilder() -> String {
//        return "child_builder"
//    }
//    
//    override func setUp() {
//        super.setUp()
//        
//        rootBuilderStore = BuilderStore()
//        
//        parentBuilderStore = BuilderStore()
//        parentBuilderStore.parent = rootBuilderStore
//        
//        childBuilderStore = BuilderStore()
//        childBuilderStore.parent = parentBuilderStore
//    }
//    
//    override func tearDown() {
//        defer { super.tearDown() }
//        
//        rootBuilderStore = nil
//        parentBuilderStore = nil
//        childBuilderStore = nil
//    }
//    
//    // MARK: - Set / Get through hierarchy
//    
//    func test_set_then_get_should_retrieve_the_builder_registered_in_the_child_first() {
//        
//        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
//        parentBuilderStore.set(builder: parentBuilder, scope: .container, for: instanceKey)
//        childBuilderStore.set(builder: childBuilder, scope: .graph, for: instanceKey)
//
//        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
//        
//        XCTAssertEqual(builder?(), "child_builder")
//    }
//    
//    func test_set_then_get_should_retrieve_the_builder_registered_in_the_parent_when_its_child_has_not_it_set() {
//        
//        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
//        parentBuilderStore.set(builder: parentBuilder, scope: .container, for: instanceKey)
//        
//        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
//        
//        XCTAssertEqual(builder?(), "parent_builder")
//    }
//    
//    func test_set_then_get_should_retrieve_the_builder_registered_in_the_root_when_no_child_has_it_set_and_the_builder_is_not_shared_with_children() {
//        
//        rootBuilderStore.set(builder: rootBuilder, scope: .graph, for: instanceKey)
//        
//        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
//        
//        XCTAssertNil(builder)
//    }
//    
//    func test_set_then_get_should_retrieve_the_builder_registered_in_the_root_when_the_child_has_not_it_set_and_the_parent_has_it_set_but_not_shared_with_children() {
//        
//        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
//        parentBuilderStore.set(builder: parentBuilder, scope: .graph, for: instanceKey)
//
//        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
//        
//        XCTAssertEqual(builder?(), "root_builder")
//    }
//}
