//
//  BuilderStoreTests.swift
//  BeaverDITests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation
import XCTest

@testable import BeaverDI

final class BuilderStoreTests: XCTestCase {

    var rootBuilderStore: BuilderStore!
    var parentBuilderStore: BuilderStore!
    var childBuilderStore: BuilderStore!
    
    let instanceKey = InstanceKey(for: String.self)
    
    func rootBuilder() -> String {
        return "root_builder"
    }
    
    func parentBuilder() -> String {
        return "parent_builder"
    }
    
    func childBuilder() -> String {
        return "child_builder"
    }
    
    override func setUp() {
        super.setUp()
        
        rootBuilderStore = BuilderStore()
        
        parentBuilderStore = BuilderStore()
        parentBuilderStore.parent = rootBuilderStore
        
        childBuilderStore = BuilderStore()
        childBuilderStore.parent = parentBuilderStore
    }
    
    // MARK: - Set / Get through hierarchie
    
    func testSetThenGetShouldRetrieveTheBuilderRegisteredInTheChildFirst() {
        
        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
        parentBuilderStore.set(builder: parentBuilder, scope: .container, for: instanceKey)
        childBuilderStore.set(builder: childBuilder, scope: .graph, for: instanceKey)

        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
        
        XCTAssertEqual(builder?(), "child_builder")
    }
    
    func testSetThenGetShouldRetrieveTheBuilderRegisteredInTheParentWhenItsChildHasNotItSet() {
        
        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
        parentBuilderStore.set(builder: parentBuilder, scope: .container, for: instanceKey)
        
        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
        
        XCTAssertEqual(builder?(), "parent_builder")
    }
    
    func testSetThenGetShouldNotRetrieveTheBuilderRegisteredInTheRootWhenNoChildHasItSetAndTheBuilderIsNotSharedWithChildren() {
        
        rootBuilderStore.set(builder: rootBuilder, scope: .graph, for: instanceKey)
        
        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
        
        XCTAssertNil(builder)
    }
    
    func testSetThenGetShouldRetrieveTheBuilderRegisteredInTheRootWhenTheChildHasNotItSetAndTheParentHasItSetButNotSharedWithChildren() {
        
        rootBuilderStore.set(builder: rootBuilder, scope: .container, for: instanceKey)
        parentBuilderStore.set(builder: parentBuilder, scope: .graph, for: instanceKey)

        let builder: (() -> String)? = childBuilderStore.get(for: instanceKey)
        
        XCTAssertEqual(builder?(), "root_builder")
    }
}
