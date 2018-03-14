//
//  InspectorTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 3/11/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import BeaverDICodeGen

final class InspectorTests: XCTestCase {
    
    func test_inspector_should_build_a_valid_graph() {
        
        let file = File(contents: """
final class API {
  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
}

final class SessionManager {
  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .container
}

final class Router {
  // beaverdi: api = API <- APIProtocol
}

final class LoginController {
  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
}

final class App {
  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .container

  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
  // beaverdi: sessionManager.scope = .container

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .container
  
  // beaverdi: loginController = LoginController
  // beaverdi: loginController.scope = .container
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])

            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_an_unresolvable_dependency() {
        let file = File(contents: """
final class API {
  // beaverdi: sessionManager <- SessionManagerProtocol
}

final class App {
  // beaverdi: sessionManager <- SessionManagerProtocol
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 5, dependencyName: "sessionManager", typeName: "SessionManagerProtocol", underlyingIssue: .unresolvableDependency))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_a_cyclic_dependency() {
        let file = File(contents: """
final class API {
  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
  // beaverdi: sessionManager.scope = .container
}

final class SessionManager {
  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .container
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 7, dependencyName: "sessionManager", typeName: "SessionManager", underlyingIssue: .unresolvableDependency))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
