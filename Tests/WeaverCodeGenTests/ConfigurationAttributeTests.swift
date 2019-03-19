//
//  ConfigurationAttributeTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 6/10/18.
//

import Foundation
import XCTest

@testable import WeaverCodeGen

final class ConfigurationAttributeTests: XCTestCase {
    
    // MARK: - Description
    
    func test_isIsolated_description_should_be_valid() {
        
        let attribute = ConfigurationAttribute.isIsolated(value: true)
        
        XCTAssertEqual(attribute.description, "Config Attr - isIsolated = true")
    }
    
    func test_customBuilder_description_should_be_valid() {
        
        let attribute = ConfigurationAttribute.customBuilder(value: "make")
        
        XCTAssertEqual(attribute.description, "Config Attr - builder = make")
    }
    
    func test_scope_description_should_be_valid() {
        
        let attribute = ConfigurationAttribute.scope(value: .container)
        
        XCTAssertEqual(attribute.description, "Config Attr - scope = container")
    }
    
    func test_does_support_objc_description_should_be_valid() {
        
        let attribute = ConfigurationAttribute.doesSupportObjc(value: true)
        
        XCTAssertEqual(attribute.description, "Config Attr - objc = true")
    }
}

final class ConfigurationAttributeTargetTests: XCTestCase {
    
    // MARK: - Description
    
    func test_self_description_should_be_valid() {
        let target = ConfigurationAttributeTarget.`self`
        
        XCTAssertEqual(target.description, "self")
    }
    
    func test_dependency_description_should_be_valid() {
        let target = ConfigurationAttributeTarget.dependency(name: "test")
        
        XCTAssertEqual(target.description, "test")
    }
}
