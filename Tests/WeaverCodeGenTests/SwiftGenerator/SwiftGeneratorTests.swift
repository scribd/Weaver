//
//  SwiftGeneratorTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 3/4/18.
//

import Foundation
import XCTest
import SourceKittenFramework
import PathKit

@testable import WeaverCodeGen

final class SwiftGeneratorTests: XCTestCase {
    
    func test_no_annotation() {
        do {
            let actual = try actualOutput()
            XCTAssertNil(actual)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_no_annotation_with_detailed_resolvers() {
        do {
            let actual = try actualOutput(detailedResolvers: true)
            XCTAssertNil(actual)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_empty_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_isolated_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_custom_builder_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_embedded_injectable_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_optional_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_public_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_open_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_ignored_types() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_internal_registration_in_public_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_generic_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_complex_generic_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_injectable_type_with_indirect_references() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_registrations_only() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_root_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_multi_generics_type_registration() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func test_objc_compatible_container() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_detailed_resolvers() {
        do {
            try performTest(detailedResolvers: true)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func test_objc_compatible_detailed_resolvers() {
        do {
            try performTest(detailedResolvers: true)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func test_nested_type() {
        do {
            try performTest()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

// MARK: - Utils

private extension SwiftGeneratorTests {
    
    var version: String { return "0.12.4" }
    
    func actualOutput(detailedResolvers: Bool = false, function: StringLiteralType = #function) throws -> String? {
        let fileName = function.replacingOccurrences(of: "()", with: "")
        let path = Path(#file).parent() + Path("Input/\(fileName).swift")

        if !path.exists {
            try path.write("\n")
        }
        
        guard let file = File(path: path.string) else {
            XCTFail("Could not find file at path \(path.string)")
            return nil
        }

        let resourcesDirectory = Path(#file).parent().parent().parent().parent() + "Resources"
        let mainTemplatePath = resourcesDirectory + "dependency_resolver.stencil"
        let detailedResolversTemplatePath = resourcesDirectory + "detailed_resolvers.stencil"
        
        let lexer = Lexer(file, fileName: "test.swift")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens, fileName: "test.swift")
        let ast = try parser.parse()
        let dependencyGraph = try Linker(syntaxTrees: [ast]).dependencyGraph
        
        let generator = try SwiftGenerator(dependencyGraph: dependencyGraph,
                                           detailedResolvers: detailedResolvers,
                                           version: version,
                                           mainTemplate: mainTemplatePath,
                                           detailedResolversTemplate: detailedResolversTemplatePath)

        guard let actual: String = try generator.generate() else {
            return nil
        }
        
        return actual + "\n"
    }
    
    func expectedOutput(actual: String?, _ function: StringLiteralType = #function) throws -> String {
        let fileName = function.replacingOccurrences(of: "()", with: "")
        let path = Path(#file).parent() + Path("Output/Weaver.\(fileName).swift")
        
        if let actual = actual, try (!path.exists || (path.read() as String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            try path.write(actual)
        }
        
        return try path.read()
    }
    
    func exportDiff(actual: String, expected: String, _ function: StringLiteralType = #function) throws {
        
        guard actual != expected else { return }

        let dirPath = Path("/tmp/weaver_tests/\(SwiftGeneratorTests.self)")
        let function = function.replacingOccurrences(of: "()", with: "")
        let actualFilePath = dirPath + Path("\(function)_actual.swift")
        let expectedFilePath = dirPath + Path("\(function)_expected.swift")

        try dirPath.mkpath()
        try actualFilePath.write(actual)
        try expectedFilePath.write(expected)
        
        print("Execute the following to check the diffs:")
        print("\n")
        print("diffchecker \(actualFilePath.string) \(expectedFilePath.string)")
        print("\n")
    }
    
    func performTest(detailedResolvers: Bool = false, function: StringLiteralType = #function) throws {
        let actual = try actualOutput(detailedResolvers: detailedResolvers, function: function)
        let expected = try expectedOutput(actual: actual, function)
        
        XCTAssertEqual(actual!, expected)
        try actual.flatMap { try exportDiff(actual: $0, expected: expected, function) }
    }
}
