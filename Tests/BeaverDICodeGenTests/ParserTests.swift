//
//  ParserTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import BeaverDICodeGen

final class ParserTests: XCTestCase {
    
    func test_parser_should_generate_a_valid_syntax_tree() {
        
        let file = File(contents: """
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  final class MyEmbeddedService {

    // beaverdi: session = Session? <- SessionProtocol?
    // beaverdi: session.scope = .container
  }

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}

class AnotherService {
    // This class is ignored
}
""")

        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)

            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 448, line: 0),
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 66, length: 38, line: 3)),
                                                                         .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 106, length: 32, line: 4)),
                                                                         .registerAnnotation(TokenBox(value: RegisterAnnotation(name: "router", typeName: "Router", protocolName: "RouterProtocol"), offset: 141, length: 47, line: 6)),
                                                                         .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "router", scope: .parent), offset: 190, length: 36, line: 7)),
                                                                         .typeDeclaration(TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 235, length: 130, line: 9),
                                                                                          children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session?", protocolName: "SessionProtocol?"), offset: 266, length: 52, line: 11)),
                                                                                                     .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "session", scope: .container), offset: 322, length: 40, line: 12))])])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_return_an_empty_file_when_there_is_no_declaration_in_the_file() {
        
        let file = File(contents: """
class Test {
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            
            let syntaxTree = try parser.parse()
            
            XCTAssertEqual(syntaxTree, .file(types: []))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_return_an_empty_file_when_the_file_is_empty() {
        
        let file = File(contents: "")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        let syntaxTree = try? parser.parse()
        
        XCTAssertEqual(syntaxTree, .file(types: []))
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_scope_is_declared_without_any_dependency_registration() {
        
        let file = File(contents: """
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  final class MyEmbeddedService {

    // beaverdi: session = Session <- SessionProtocol?
    // beaverdi: session.scope = .container
  }

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? ParserError, .unknownDependency(line: 3, dependencyName: "api"))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_twice() {
        
        let file = File(contents: """
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: api = API <- APIProtocol

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  final class MyEmbeddedService {

    // beaverdi: session = Session? <- SessionProtocol?
    // beaverdi: session.scope = .container
  }

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? ParserError, .depedencyDoubleDeclaration(line: 6, dependencyName: "api"))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_outside_of_a_type() {
        
        let file = File(contents: """
  // beaverdi: api = API <- APIProtocol
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? ParserError, .unexpectedToken(line: 0))
        }
    }
}
