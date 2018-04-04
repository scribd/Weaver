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
}

final class Router {
  // beaverdi: api <- APIProtocol
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
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
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
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 1, file: "test.swift", dependencyName: "sessionManager", typeName: "SessionManagerProtocol", underlyingError: .unresolvableDependency))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_a_cyclic_dependency() {
        let file = File(contents: """
final class API {
    // beaverdi: session = Session <- SessionProtocol
    // beaverdi: session.scope = .container
}

final class Session {
    // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
    // beaverdi: sessionManager.scope = .container

    // beaverdi: sessionManager1 = SessionManager <- SessionManagerProtocol
    // beaverdi: sessionManager1.scope = .transient
}

final class SessionManager {
    // beaverdi: api = API <- APIProtocol
    // beaverdi: api.scope = .weak
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 9, file: "test.swift", dependencyName: "sessionManager1", typeName: "SessionManager", underlyingError: .cyclicDependency))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_inspector_should_build_a_valid_graph_with_a_lazy_loaded_dependency_cycle() {
        let file = File(contents: """
final class API {
    // beaverdi: session = Session <- SessionProtocol
    // beaverdi: session.scope = .container
}

final class Session {
    // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
    // beaverdi: sessionManager.scope = .container

    // beaverdi: sessionManager1 = SessionManager <- SessionManagerProtocol
    // beaverdi: sessionManager1.scope = .container
}

final class SessionManager {
    // beaverdi: api = API <- APIProtocol
    // beaverdi: api.scope = .weak
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_an_unresolvable_ref_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class API {
    // beaverdi: api <- APIProtocol
    // beaverdi: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_an_unbuildable_dependency_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class API {
    // beaverdi: api = API <- APIProtocol
    // beaverdi: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
