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
    
    func test_parser_should_generate_a_valid_syntax_tree_with_an_embedded_dependency() {
        let file = File(contents: """
final class MyService {
  final class MyEmbeddedService {
    // beaverdi: session = Session <- SessionProtocol
  }
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 111, line: 0),
                                                              children: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 32, length: 83, line: 1),
                                                                                          children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session", protocolName: "SessionProtocol"), offset: 62, length: 50, line: 2))])])])

            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_and_a_scope() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()

            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 93, line: 0),
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 26, length: 38, line: 1)),
                                                                         .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 66, length: 32, line: 2))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_and_an_optional_type() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api = API <- APIProtocol?
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 60, line: 0),
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol?"), offset: 26, length: 39, line: 1))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 59, line: 0),
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 26, length: 38, line: 1))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_but_no_protocol() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api = API
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 44, line: 0),
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: nil), offset: 26, length: 23, line: 1))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_reference() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 53, line: 0),
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 32, line: 1))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_add_a_scope_to_a_reference() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api <- APIProtocol
  // beaverdi: api.scope = .graph
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unknownDependency(line: 2, dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_declare_a_reference_and_a_registration_with_the_same_name() {
        let file = File(contents: """
final class MyService {
  // beaverdi: api <- APIProtocol
  // beaverdi: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
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
    
    func test_parser_should_return_ignore_types_with_no_dependencies() {
        
        let file = File(contents: """
final class MyService {
  // beaverdi: api <- APIProtocol
}

class Test {
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 53, line: 0),
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 32, line: 1))])])
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_return_an_empty_file_when_the_file_is_empty() {
        
        let file = File(contents: "")

        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
        
            let syntaxTree = try parser.parse()
            XCTAssertEqual(syntaxTree, .file(types: []))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_scope_is_declared_without_any_dependency_registration() {
        
        let file = File(contents: """
final class MyService {
  // beaverdi: api.scope = .graph
}
""")
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)

            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unknownDependency(line: 1, dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_twice() {
        
        let file = File(contents: """
final class MyService {
  // beaverdi: api = API <- APIProtocol
  // beaverdi: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)

            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_outside_of_a_type() {
        
        let file = File(contents: """
// beaverdi: api = API <- APIProtocol
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)

            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unexpectedToken(line: 0))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
}
