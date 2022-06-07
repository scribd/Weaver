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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[109] - at line: 0
                |-- internal MyService.MyEmbeddedService { - 32[81] - at line: 1
                |-- Register - session = Session <- SessionProtocol - 62[48] - at line: 2
                """)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_and_a_scope() {
        let file = File(contents: """
            final class MyService {
              // weaver: api = API <- APIProtocol
              // weaver: api.scope = .container
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[93] - at line: 0
                |-- Register - api = API <- APIProtocol - 26[36] - at line: 1
                |-- Configuration - api.Config Attr - scope = container - 64[34] - at line: 2
                """)
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[58] - at line: 0
                |-- Register - api = API <- Optional<APIProtocol> - 26[37] - at line: 1
                """)
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[57] - at line: 0
                |-- Register - api = API <- APIProtocol - 26[36] - at line: 1
                """)
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[42] - at line: 0
                |-- Register - api = API - 26[21] - at line: 1
                """)
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[51] - at line: 0
                |-- Reference - api <- APIProtocol - 26[30] - at line: 1
                """)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_trying_to_set_custom_builder_on_an_unknown_reference() {
        let file = File(contents: """
            final class MyService {
              // weaver: api.builder = MyService.make
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error.description, "test.swift:2: error: Unknown dependency: 'api'.")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_reference_with_a_custom_builder() {
        let file = File(contents: """
            final class MyService {
              // weaver: api <- APIProtocol
              // weaver: api.builder = MyService.make
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()

            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[93] - at line: 0
                |-- Reference - api <- APIProtocol - 26[30] - at line: 1
                |-- Configuration - api.Config Attr - builder = MyService.make - 58[40] - at line: 2
                """)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_parser_should_generate_a_valid_syntax_tree_with_a_dependency_registration_with_custom_a_builder() {
        let file = File(contents: """
            final class MyService {
              // weaver: api = API <- APIProtocol
              // weaver: api.builder = API.make
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[93] - at line: 0
                |-- Register - api = API <- APIProtocol - 26[36] - at line: 1
                |-- Configuration - api.Config Attr - builder = API.make - 64[34] - at line: 2
                """)
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
            XCTAssertEqual(error.description, "test.swift:3: error: Double dependency declaration: 'api'.")
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]

                """)
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[51] - at line: 0
                |-- Reference - api <- APIProtocol - 26[30] - at line: 1
                """)
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

            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]

                """)
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_a_scope_is_declared_without_any_dependency_registration() {
        
        let file = File(contents: """
            final class MyService {
              // weaver: api.scope = .container
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error.description, "test.swift:2: error: Unknown dependency: 'api'.")
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
            XCTAssertEqual(error.description, "test.swift:3: error: Double dependency declaration: 'api'.")
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
            XCTAssertEqual(error.description, "test.swift:1: error: Unexpected token.")
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

            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MovieManager { - 6[52] - at line: 0
                |-- Parameter - movieID <= Optional<UInt> - 29[28] - at line: 1
                """)
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
            XCTAssertEqual(error.description, "test.swift:3: error: Double dependency declaration: 'movieID'.")
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
            XCTAssertEqual(error.description, "test.swift:3: error: Double dependency declaration: 'movieID'.")
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
            XCTAssertEqual(error.description, "test.swift:3: error: Double dependency declaration: 'movieID'.")
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
            
            XCTAssertEqual(syntaxTree.description, """
                File[test.swift]
                |- internal MyService { - 6[87] - at line: 0
                |-- Reference - api <- APIProtocol - 26[30] - at line: 1
                |-- Configuration - self.Config Attr - isIsolated = true - 58[34] - at line: 2
                """)
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
            XCTAssertEqual(error.description, "test.swift:4: error: Configuration attribute 'isIsolated' was already set.")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_syntax_error_when_objc_config_attribute_is_set_on_self() {
        let file = File(contents: """
            final class MyService {
              // weaver: self.objc = true
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "test.swift:2: error: Can't assign configuration attribute 'objc' on 'self'.")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_parser_should_generate_a_parser_error_when_trying_to_use_an_incompatible_attribute() {
        let file = File(contents: """
            final class MyService {
              // weaver: api <- APIProtocol
              // weaver: api.objc = true
            }
            """)
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            
            _ = try parser.parse()
            XCTFail("An error was expected.")
        } catch let error as ParserError {
            XCTAssertEqual(error.description, "test.swift:3: error: Configuration attribute 'doesSupportObjc' cannot be used on dependency 'api'.")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
}
