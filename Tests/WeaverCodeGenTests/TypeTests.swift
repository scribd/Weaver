//
//  SwiftTypeTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation
import XCTest

@testable import WeaverCodeGen

final class SwiftTypeTests: XCTestCase {
    
    // MARK: - init
    
    func test_init_should_build_correctly_with_a_valid_generic_type() {
        do {
            let type = try SwiftType("Test<A, B, C, D, E, F>")
            
            XCTAssertEqual(type, SwiftType(
                name: "Test",
                genericNames: ["A", "B", "C", "D", "E", "F"]
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_nongeneric_type() {
        do {
            let type = try SwiftType("Test")
            
            XCTAssertEqual(type, SwiftType(
                name: "Test"
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_not_build_with_an_invalid_generic_type() {
        do {
            let type = try SwiftType("Test<>")
            
            XCTAssertNil(type)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_non_generic_optional_type() {
        do {
            let type = try SwiftType("Test?")
            
            XCTAssertEqual(type, SwiftType(
                name: "Test",
                genericNames: [],
                isOptional: true
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_generic_optional_type() {
        do {
            let type = try SwiftType("Test<A, B, C, D, E, F>?")
            
            XCTAssertEqual(type, SwiftType(
                name: "Test",
                genericNames: ["A", "B", "C", "D", "E", "F"],
                isOptional: true
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_nested_types() {
        do {
            let type = try SwiftType("Test.NestedType<A, B.NestedType, C, D, E, F>?")

            XCTAssertEqual(type, SwiftType(
                name: "Test.NestedType",
                genericNames: ["A", "B.NestedType", "C", "D", "E", "F"],
                isOptional: true
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Description
    
    func test_description_should_return_a_valid_swift_type_with_generics() {
        XCTAssertEqual(SwiftType(name: "Test", genericNames: ["A", "B", "C"]).description, "Test<A, B, C>")
    }
    
    func test_description_should_return_a_valid_swift_type_with_no_generics() {
        XCTAssertEqual(SwiftType(name: "Test").description, "Test")
    }
    
    func test_description_should_return_a_valid_swift_type_with_no_generics_but_optional() {
        XCTAssertEqual(SwiftType(name: "Test", isOptional: true).description, "Test?")
    }

    func test_description_should_return_a_valid_swift_type_with_generics_but_optional() {
        XCTAssertEqual(SwiftType(name: "Test", genericNames: ["A", "B", "C"], isOptional: true).description, "Test<A, B, C>?")
    }
}
