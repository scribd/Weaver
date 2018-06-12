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

    private var errorDescription: String!
    
    private var expectedDescription: String!
    
    override func tearDown() {
        defer { super.tearDown() }
        
        errorDescription = nil
        expectedDescription = nil
    }
    
    // MARK: - TokenError
    
    func test_tokenError_invalidAnnotation_description() {
        
        errorDescription = TokenError.invalidAnnotation("fake_annotation").description
        expectedDescription = "Invalid annotation: 'fake_annotation'"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_tokenError_invalidScope_description() {
        
        errorDescription = TokenError.invalidScope("fake_annotation").description
        expectedDescription = "Invalid scope: 'fake_annotation'"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_tokenError_invalidConfigurationAttributeValue_description() {
        
        errorDescription = TokenError.invalidConfigurationAttributeValue(value: "fake_value", expected: "fake_expected_value").description
        expectedDescription = "Invalid configuration attribute value: 'fake_value'. Expected 'fake_expected_value'"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    // MARK: - LexerError
    
    func test_lexerError_invalidAnnotation_description() {
        
        errorDescription = LexerError.invalidAnnotation(FileLocation(line: 42, file: "fake_file.swift"),
                                                        underlyingError: .invalidAnnotation("fake_annotation")).description
        expectedDescription = "fake_file.swift:43: error: Invalid annotation: 'fake_annotation'."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    // MARK: - ParserError
    
    func test_parserError_dependencyDoubleDeclaration_description() {
        
        errorDescription = ParserError.dependencyDoubleDeclaration(PrintableDependency(fileLocation:  FileLocation(line: 42, file: "fake_file.swift"),
                                                                                      name: "fake_dependency",
                                                                                      typeName: nil)).description
        expectedDescription = "fake_file.swift:43: error: Double dependency declaration: 'fake_dependency'."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_parserError_unexpectedEOF_description() {
        
        errorDescription = ParserError.unexpectedEOF(FileLocation(line: nil, file: "fake_file.swift")).description
        expectedDescription = "fake_file.swift:1: error: Unexpected EOF (End of file)."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_parserError_unexpectedToken_description() {
        
        errorDescription = ParserError.unexpectedToken(FileLocation(line: 42, file: "fake_file.swift")).description
        expectedDescription = "fake_file.swift:43: error: Unexpected token."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_parserError_unknownDependency_description() {
        
        errorDescription = ParserError.unknownDependency(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                             name: "fake_dependency",
                                                                             typeName: "fake_dependency")).description
        expectedDescription = "fake_file.swift:43: error: Unknown dependency: 'fake_dependency'."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_parserError_configurationAttributeDoubleAssignation_description() {
        
        errorDescription = ParserError.configurationAttributeDoubleAssignation(FileLocation(line: 42, file: "fake_file.swift"),
                                                                               attribute: .isIsolated(value: true)).description
        expectedDescription = "fake_file.swift:43: error: Configuration attribute 'isIsolated' was already set."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    // MARK: - GeneratorError
    
    func test_generatorError_invalidTemplatePath_description() {
        
        errorDescription = GeneratorError.invalidTemplatePath(path: "fake_file.swift").description
        expectedDescription = "Invalid template path: fake_file.swift."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    // MARK: - InspectorError
    
    func test_inspectorError_invalidAST_description() {
    
        let unexpectedExpr = Expr.scopeAnnotation(TokenBox<ScopeAnnotation>(value: ScopeAnnotation(name: "fake_dependency", scope: .graph),
                                                                            offset: 42,
                                                                            length: 24,
                                                                            line: 1))
        errorDescription = InspectorError.invalidAST(FileLocation(line: nil, file: "fake_file.swift"), unexpectedExpr: unexpectedExpr).description

        expectedDescription = "fake_file.swift:1: error: Invalid AST because of token: Scope - fake_dependency.scope = graph - 42[24] - at line: 1."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_inspectorError_invalidGraph_description() {
        
        errorDescription = InspectorError.invalidGraph(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                           name: "fake_dependency",
                                                                           typeName: "fake_type"),
                                                       underlyingError: .cyclicDependency(history: [])).description
        
        expectedDescription = "fake_file.swift:43: error: Detected invalid dependency graph starting with 'fake_dependency: fake_type'. Detected a cyclic dependency."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_inspectorError_invalidGraph_unresolvableDependency_description() {

        let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
            InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                                  name: "fake_dependecy",
                                                                                  typeName: "fake_type"))
        ])
        errorDescription = InspectorError.invalidGraph(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                           name: "fake_dependency",
                                                                           typeName: "fake_type"),
                                                       underlyingError: underlyingError).description
        
        expectedDescription = """
        fake_file.swift:43: error: Detected invalid dependency graph starting with 'fake_dependency: fake_type'. Dependency cannot be resolved.
        fake_file.swift:43: warning: Could not find the dependency 'fake_dependecy' in 'fake_type'. You may want to register it here to solve this issue.
        """
        
        XCTAssertEqual(errorDescription!, expectedDescription!)
    }
    
    func test_inspectorError_invalidGraph_isolatedResolverCannotHaveReferents_description() {
        
        let underlyingError = InspectorAnalysisError.isolatedResolverCannotHaveReferents(typeName: "fake_type", referents: [
            PrintableResolver(fileLocation: FileLocation(line: 42, file: "fake_file.swift"), typeName: "fake_type")
        ])
        errorDescription = InspectorError.invalidGraph(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                           name: "fake_dependency",
                                                                           typeName: "fake_type"),
                                                       underlyingError: underlyingError).description
        
        expectedDescription = """
        fake_file.swift:43: error: Detected invalid dependency graph starting with 'fake_dependency: fake_type'. This type is flagged as isolated. It cannot have any connected referent.
        fake_file.swift:43: error: 'fake_type' cannot depend on 'fake_type' because it is flagged as 'isolated'. You may want to set 'fake_type.isIsolated' to 'false'.
        """
        
        XCTAssertEqual(errorDescription!, expectedDescription!)
    }
    
    // MARK: - InspectorAnalysisError
    
    func test_inspectorAnalysisError_InspectorAnalysisError_description() {
        
        errorDescription = InspectorAnalysisError.cyclicDependency(history: []).description
        expectedDescription = "Detected a cyclic dependency"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_inspectorAnalysisError_unresolvableDependency_description() {
        
        errorDescription = InspectorAnalysisError.unresolvableDependency(history: []).description
        expectedDescription = "Dependency cannot be resolved"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_inspectorAnalysisError_isolatedResolverCannotHaveReferents_description() {
        
        errorDescription = InspectorAnalysisError.isolatedResolverCannotHaveReferents(typeName: "fake_type", referents: []).description
        expectedDescription = "This type is flagged as isolated. It cannot have any connected referent"
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    // MARK: - InspectorAnalysisHistoryRecord
    
    func test_inspectorAnalysisHistoryRecord_isolatedResolverCannotHaveReferents_description() {
        
        errorDescription = InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                                                 name: "fake_dependency",
                                                                                                 typeName: "fake_type")).description

        expectedDescription = "fake_file.swift:43: warning: Could not find the dependency 'fake_dependency' in 'fake_type'. You may want to register it here to solve this issue."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
    
    func test_inspectorAnalysisHistoryRecord_foundUnaccessibleDependency_description() {
        
        errorDescription = InspectorAnalysisHistoryRecord.foundUnaccessibleDependency(PrintableDependency(fileLocation: FileLocation(line: 42, file: "fake_file.swift"),
                                                                                                          name: "fake_dependency",
                                                                                                          typeName: "fake_type")).description

        expectedDescription = "fake_file.swift:43: warning: Found unaccessible dependency 'fake_dependency' in 'fake_type'. You may want to set its scope to '.container' or '.weak' to solve this issue."
        
        XCTAssertEqual(errorDescription, expectedDescription)
    }
}
