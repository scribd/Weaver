//
//  ErrorTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 5/19/18.
//

import Foundation
import XCTest

@testable import WeaverCodeGen

final class ErrorTests: XCTestCase {

    // MARK: - TokenError
    
    func test_tokenError_description() {
        
        XCTAssertEqual(TokenError.invalidAnnotation("fake_annotation").description, "Invalid annotation: 'fake_annotation'")
        
        XCTAssertEqual(TokenError.invalidScope("fake_annotation").description, "Invalid scope: 'fake_annotation'")

        XCTAssertEqual(TokenError.invalidCustomRefValue("fake_annotation").description, "Invalid customRef value: fake_annotation. Expected true|false")
        
        XCTAssertEqual(TokenError.invalidConfigurationAttributeValue(value: "fake_value", expected: "fake_expected_value").description, "Invalid configuration attribute value: fake_value. Expected fake_expected_value")
    }
    
    // MARK: - LexerError
    
    func test_lexerError_description() {
        
        XCTAssertEqual(LexerError.invalidAnnotation(line: 42, file: "fake_file.swift", underlyingError: .invalidAnnotation("fake_annotation")).description, "fake_file.swift:43: error: Invalid annotation: 'fake_annotation'.")
    }
    
    // MARK: - ParserError
    
    func test_parserError_description() {
        
        XCTAssertEqual(ParserError.depedencyDoubleDeclaration(line: 42, file: "fake_file.swift", dependencyName: "fake_dependency").description, "fake_file.swift:43: error: Double dependency declaration: 'fake_dependency'.")
        
        XCTAssertEqual(ParserError.unexpectedEOF(file: "fake_file.swift").description, "fake_file.swift:1: error: Unexpected EOF (End of file).")
        
        XCTAssertEqual(ParserError.unexpectedToken(line: 42, file: "fake_file.swift").description, "fake_file.swift:43: error: Unexpected token.")
        
        XCTAssertEqual(ParserError.unknownDependency(line: 42, file: "fake_file.swift", dependencyName: "fake_dependency").description, "fake_file.swift:43: error: Unknown dependency: 'fake_dependency'.")
        
        XCTAssertEqual(ParserError.configurationAttributeDoubleAssignation(line: 42, file: "fake_file.swift", attribute: .isIsolated(value: true)).description, "fake_file.swift:43: error: Configuration attribute 'isIsolated' was already set.")
    }
    
    // MARK: - GeneratorError
    
    func test_generatorError_description() {
        
        XCTAssertEqual(GeneratorError.invalidTemplatePath(path: "fake_file.swift").description, "Invalid template path: fake_file.swift.")
    }
    
    // MARK: - InspectorError
    
    func test_inspectorError_description() {
        
        XCTAssertEqual(InspectorError.invalidAST(unexpectedExpr: .scopeAnnotation(TokenBox<ScopeAnnotation>(value: ScopeAnnotation(name: "fake_dependency", scope: .graph), offset: 42, length: 24, line: 1)), file: "fake_file.swift").description,
                       "fake_file.swift: error: Invalid AST because of token: Scope - fake_dependency.scope = graph - 42[24] - at line: 1.")

        XCTAssertEqual(InspectorError.invalidGraph(line: 42, file: "fake_file.swift", dependencyName: "fake_dependency", typeName: "fake_type", underlyingError: .cyclicDependency).description, "fake_file.swift:43: error: The dependency graph is invalid. Detected a cyclic dependency.")
        
        XCTAssertEqual(InspectorError.invalidGraph(line: 42, file: "fake_file.swift", dependencyName: "fake_dependency", typeName: "fake_type", underlyingError: .unresolvableDependency(history: [.dependencyNotFound(line: 42, file: "fake_file.swift", name: "fake_dependecy", typeName: "fake_type")])).description, """
fake_file.swift:43: error: The dependency graph is invalid. Dependency cannot be resolved.
fake_file.swift:43: warning: Could not find the dependency 'fake_dependecy' in 'fake_type'. You may want to register it here to solve this issue.
""")
    }
    
    // MARK: - InspectorAnalysisError
    
    func test_inspectorAnalysisError_description() {
        
        XCTAssertEqual(InspectorAnalysisError.cyclicDependency.description, "Detected a cyclic dependency")

        XCTAssertEqual(InspectorAnalysisError.unresolvableDependency(history: []).description, "Dependency cannot be resolved")
        
        XCTAssertEqual(InspectorAnalysisError.isolatedResolverCannotHaveReferents(typeName: "fake_type", referents: []).description, "This type is flagged as isolated. It cannot have any connected referent")
    }
}
