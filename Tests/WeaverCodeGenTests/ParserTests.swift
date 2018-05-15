//
//  ParserTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class ParserTests: XCTestCase {
    
    func test_parser_should_generate_a_valid_syntax_tree_with_an_embedded_dependency() {
        let file = File(contents: """
final class MyService {
  final class MyEmbeddedService {
    // weaver: session = Session <- SessionProtocol
  }
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 109, line: 0),
                                                              config: [],
                                                              children: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyEmbeddedService", accessLevel: .default), offset: 32, length: 81, line: 1),
                                                                                          config: [],
                                                                                          children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session", protocolName: "SessionProtocol"), offset: 62, length: 48, line: 2))])])],
                                     name: "test.swift")

            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_and_a_scope() {
        let file = File(contents: """
final class MyService {
  // weaver: api = API <- APIProtocol
  // weaver: api.scope = .graph
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()

            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 89, line: 0),
                                                              config: [],
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 26, length: 36, line: 1)),
                                                                         .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 64, length: 30, line: 2))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_and_an_optional_type() {
        let file = File(contents: """
final class MyService {
  // weaver: api = API <- APIProtocol?
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 58, line: 0),
                                                              config: [],
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol?"), offset: 26, length: 37, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration() {
        let file = File(contents: """
final class MyService {
  // weaver: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 57, line: 0),
                                                              config: [],
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 26, length: 36, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_but_no_protocol() {
        let file = File(contents: """
final class MyService {
  // weaver: api = API
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 42, line: 0),
                                                              config: [],
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: nil), offset: 26, length: 21, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_reference() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 51, line: 0),
                                                              config: [],
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 30, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_add_a_scope_to_a_reference() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
  // weaver: api.scope = .graph
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unknownDependency(line: 2, file: "test.swift", dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_set_custom_ref_on_an_unknown_reference() {
        let file = File(contents: """
final class MyService {
  // weaver: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unknownDependency(line: 1, file: "test.swift", dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_reference_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
  // weaver: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 85, line: 0),
                                                              config: [],
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 30, line: 1)),
                                                                         .customRefAnnotation(TokenBox(value: CustomRefAnnotation(name: "api", value: true), offset: 58, length: 32, line: 2))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class MyService {
  // weaver: api = API <- APIProtocol
  // weaver: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 91, line: 0),
                                                              config: [],
                                                              children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 26, length: 36, line: 1)),
                                                                         .customRefAnnotation(TokenBox(value: CustomRefAnnotation(name: "api", value: true), offset: 64, length: 32, line: 2))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_declare_a_reference_and_a_registration_with_the_same_name() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
  // weaver: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, file: "test.swift", dependencyName: "api"))
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
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            let syntaxTree = try parser.parse()
            
            XCTAssertEqual(syntaxTree, .file(types: [], name: "test.swift"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_return_ignore_types_with_no_dependencies() {
        
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
}

class Test {
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 51, line: 0),
                                                              config: [],
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 30, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_return_an_empty_file_when_the_file_is_empty() {
        
        let file = File(contents: "")

        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            let syntaxTree = try parser.parse()
            XCTAssertEqual(syntaxTree, .file(types: [], name: "test.swift"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_scope_is_declared_without_any_dependency_registration() {
        
        let file = File(contents: """
final class MyService {
  // weaver: api.scope = .graph
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unknownDependency(line: 1, file: "test.swift", dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_twice() {
        
        let file = File(contents: """
final class MyService {
  // weaver: api = API <- APIProtocol
  // weaver: api = API <- APIProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, file: "test.swift", dependencyName: "api"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_dependency_is_declared_outside_of_a_type() {
        
        let file = File(contents: """
// weaver: api = API <- APIProtocol
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")

            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .unexpectedToken(line: 0, file: "test.swift"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_parameter_declaration() {
        let file = File(contents: """
final class MovieManager {
  // weaver: movieID <= UInt?
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MovieManager"), offset: 6, length: 52, line: 0),
                                                              config: [],
                                                              children: [.parameterAnnotation(TokenBox(value: ParameterAnnotation(name: "movieID", typeName: "UInt?"), offset: 29, length: 28, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_parameter_is_declared_twice() {
        
        let file = File(contents: """
final class MovieManager {
  // weaver: movieID <= UInt
  // weaver: movieID <= UInt
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, file: "test.swift", dependencyName: "movieID"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_parameter_as_the_same_name_than_a_reference() {
        
        let file = File(contents: """
final class MovieManager {
  // weaver: movieID <= UInt
  // weaver: movieID <- UInt
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, file: "test.swift", dependencyName: "movieID"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_parameter_as_the_same_name_than_a_registration() {
        
        let file = File(contents: """
final class MovieManager {
  // weaver: movieID <= UInt
  // weaver: movieID = UInt
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .depedencyDoubleDeclaration(line: 2, file: "test.swift", dependencyName: "movieID"))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_isIsolated_configuration_attribute() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
  // weaver: self.isIsolated = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 87, line: 0),
                                                              config: [TokenBox(value: ConfigurationAnnotation(attribute: .isIsolated(value: true)), offset: 58, length: 34, line: 2)],
                                                              children: [.referenceAnnotation(TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 26, length: 30, line: 1))])],
                                     name: "test.swift")
            
            XCTAssertEqual(syntaxTree, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_config_attribute_was_set_twice() {
        let file = File(contents: """
final class MyService {
  // weaver: api <- APIProtocol
  // weaver: self.isIsolated = true
  // weaver: self.isIsolated = false
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error, .configurationAttributeDoubleAssignation(line: 3, file: "test.swift", attribute: .isIsolated(value: false)))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
}
