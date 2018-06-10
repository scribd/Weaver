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
        
        XCTAssertEqual(attribute.description, "Config Attr - self.isIsolated = true")
    }
    
    func test_customRef_description_should_be_valid() {
        
        let attribute = ConfigurationAttribute.customRef(value: true)
        
        XCTAssertEqual(attribute.description, "Config Attr - dependency.customRef = true")
    }
}

final class ConfigurationAttributeTargetTests: XCTestCase {
    
    // MARK: - Description
    
    func test_self_description_should_be_valie() {
        let target = ConfigurationAttributeTarget.`self`
        
        XCTAssertEqual(target.description, "self")
    }
    
    func test_dependency_description_should_be_valie() {
        let target = ConfigurationAttributeTarget.dependency(name: "test")
        
        XCTAssertEqual(target.description, "test")
    }
}
