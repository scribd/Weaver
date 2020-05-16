//
//  AnyTypeTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation
import XCTest

@testable import WeaverCodeGen

final class AnyTypeTests: XCTestCase {
    
    func test_init_should_build_correctly_with_a_valid_generic_type() {
        do {
            let type = try CompositeType("Test<A, B, C, D, E, F>")
            XCTAssertEqual(type.description, "Test<A, B, C, D, E, F>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_nongeneric_type() {
        do {
            let type = try CompositeType("Test")
            XCTAssertEqual(type.description, "Test")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_not_build_with_an_invalid_generic_type() {
        do {
            _ = try CompositeType("Test<>")
            XCTFail("Expected error")
        } catch let error as TokenError {
            XCTAssertEqual(error.description, "Invalid token '>' in type 'Test<>'")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_non_generic_optional_type() {
        do {
            let type = try CompositeType("Test?")
            XCTAssertEqual(type.description, "Optional<Test>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_a_generic_optional_type() {
        do {
            let type = try CompositeType("Test<A, B, C, D, E, F>?")
            XCTAssertEqual(type.description, "Optional<Test<A, B, C, D, E, F>>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_nested_types() {
        do {
            let type = try CompositeType("Test.NestedType<A, B.NestedType, C, D, E, F>?")
            XCTAssertEqual(type.description, "Optional<Test.NestedType<A, B.NestedType, C, D, E, F>>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_nested_generics() {
        do {
            let type = try CompositeType("Foo<Foo.Bar<Foo<Bar.Bar?>?>?>???")
            XCTAssertEqual(type.description, "Optional<Optional<Optional<Foo<Optional<Foo.Bar<Optional<Foo<Optional<Bar.Bar>>>>>>>>>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_array() {
        do {
            let type = try CompositeType("[Foo<Bar>?]")
            XCTAssertEqual(type.description, "Array<Optional<Foo<Bar>>>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_dictionary() {
        do {
            let type = try CompositeType("[Key: [Foo<Bar>?]]")
            XCTAssertEqual(type.description, "Dictionary<Key, Array<Optional<Foo<Bar>>>>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_name_with_underscores() {
        do {
            let type = try CompositeType("Foo_Bar")
            XCTAssertEqual(type.description, "Foo_Bar")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_name_with_numbers() {
        do {
            let type = try CompositeType("Foo1")
            XCTAssertEqual(type.description, "Foo1")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_closures() {
        do {
            let type = try CompositeType("() -> Void")
            XCTAssertEqual(type.description, "(() -> Void)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_nested_closures() {
        do {
            let type = try CompositeType("() -> () -> Void")
            XCTAssertEqual(type.description, "(() -> (() -> Void))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_tuple() {
        do {
            let type = try CompositeType("(Int, Int)")
            XCTAssertEqual(type.description, "(Int, Int)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_tuple_with_named_parameters() {
        do {
            let type = try CompositeType("(foo: Int, _ bar: Int)")
            XCTAssertEqual(type.description, "(foo: Int, _ bar: Int)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_not_build_correctly_with_tuple_with_named_parameters_but_missing_colon() {
        do {
            let type = try CompositeType("(foo: Int, _ bar Int)")
            XCTAssertEqual(type.description, "(foo: Int, _ bar Int)")
        } catch let error as TokenError {
            XCTAssertEqual(error.description, "Invalid token 'Int' in type '(foo: Int, _ bar Int)'")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_closure_with_named_parameters() {
        do {
            let type = try CompositeType("(_ foo: Int, _ bar: Int) -> ()")
            XCTAssertEqual(type.description, "((_ foo: Int, _ bar: Int) -> ())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_parse_until_not_a_type_anymore() {
        do {
            let type = try CompositeType("Foo<Int, Int>: SomeProtocol")
            XCTAssertEqual(type.description, "Foo<Int, Int>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_closure_taking_a_tuple_as_a_parameter() {
        do {
            let type = try CompositeType("((foo: Int, bar: Int)) -> ()")
            XCTAssertEqual(type.description, "(((foo: Int, bar: Int)) -> ())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_closure_taking_optional_as_parameter() {
        do {
            let type = try CompositeType("(UInt, String?) -> UIViewController")
            XCTAssertEqual(type.description, "((UInt, Optional<String>) -> UIViewController)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_init_should_build_correctly_with_generic_and_constraint() {
        do {
            let type = try CompositeType("Foo<T: Bar>")
            XCTAssertEqual(type.description, "Foo<T>")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
