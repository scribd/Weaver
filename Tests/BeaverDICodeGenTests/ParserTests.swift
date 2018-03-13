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
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
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

        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)

        let syntaxTree = try? parser.parse()
        
        let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 51, length: 500, line: 1),
                                                          parentResolver: TokenBox(value: ParentResolverAnnotation(typeName: "MainDependencyResolver"), offset: 0, length: 45, line: 0),
                                                          children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 111, length: 38, line: 4)),
                                                                     .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 151, length: 32, line: 5)),
                                                                     .registerAnnotation(TokenBox(value: RegisterAnnotation(name: "router", typeName: "Router", protocolName: "RouterProtocol"), offset: 186, length: 47, line: 7)),
                                                                     .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "router", scope: .parent), offset: 235, length: 36, line: 8)),
                                                                     .typeDeclaration(TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 332, length: 130, line: 11),
                                                                                      parentResolver: TokenBox(value: ParentResolverAnnotation(typeName: "MyServiceDependencyResolver"), offset: 274, length: 50, line: 10),
                                                                                      children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session?", protocolName: "SessionProtocol?"), offset: 363, length: 52, line: 13)),
                                                                                                 .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "session", scope: .container), offset: 419, length: 40, line: 14))])])])
        
        XCTAssertEqual(syntaxTree, expected)
    }
    
    func test_parser_should_return_an_empty_file_when_there_is_no_declaration_in_the_file() {
        
        let file = File(contents: """
class Test {
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        let syntaxTree = try? parser.parse()
        
        XCTAssertEqual(syntaxTree, .file(types: []))
    }
    
    func test_parser_should_return_an_empty_file_when_the_file_is_empty() {
        
        let file = File(contents: "")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        let syntaxTree = try? parser.parse()
        
        XCTAssertEqual(syntaxTree, .file(types: []))
    }

    func test_parser_should_generate_a_syntax_error_when_a_parent_annotation_is_orfan() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver

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
            XCTAssertEqual(error as? ParserError, .unexpectedToken(line: 12))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_scope_is_declared_without_any_dependency_registration() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
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
            XCTAssertEqual(error as? ParserError, .unknownDependency(line: 4, dependencyName: "api"))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_an_injected_type_does_not_have_any_dependencies() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
  final class MyEmbeddedService {
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
            XCTAssertEqual(error as? ParserError, .missingDependency(line: 11, typeName: "MyEmbeddedService"))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_twice() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: api = API <- APIProtocol

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
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
            XCTAssertEqual(error as? ParserError, .depedencyDoubleDeclaration(line: 7, dependencyName: "api"))
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_in_a_non_injectable_type() {
        
        let file = File(contents: """
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: api = API <- APIProtocol

  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
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
            XCTAssertEqual(error as? ParserError, .unexpectedToken(line: 3))
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
