//
//  LexerTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class LexerTests: XCTestCase {
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_type_declaration() {

        let file = File(contents: """

final class MyService {
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()

            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService"), offset: 7, length: 19, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 25, length: 1, line: 2))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_embedded_type_declaration() {
        
        let file = File(contents: """

final class MyService {
  final class MyEmbeddedService {
  }
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 4 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService"), offset: 7, length: 57, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 33, length: 29, line: 2))
                XCTAssertEqual(tokens[2] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 61, length: 1, line: 3))
                XCTAssertEqual(tokens[3] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 63, length: 1, line: 4))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_public_type_declaration() {
        
        let file = File(contents: """

public final class MyService {
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .public), offset: 14, length: 19, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 32, length: 1, line: 2))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_internal_type_declaration() {
        
        let file = File(contents: """

internal final class MyService {
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .internal), offset: 16, length: 19, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 34, length: 1, line: 2))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_extension_of_ObjCDependencyInjectable() {
        
        let file = File(contents: """

extension MyService: MyServiceObjCDependencyInjectable {
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", doesSupportObjc: true), offset: 1, length: 58, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 58, length: 1, line: 2))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_annotation() {
        
        let file = File(contents: """

// weaver: api = API <- APIProtocol
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 1, length: 35, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_annotation_and_no_protocol() {
        
        let file = File(contents: """

// weaver: api = API
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: nil), offset: 1, length: 20, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_annotation_and_optional_types() {
        
        let file = File(contents: """

// weaver: api = API? <- APIProtocol?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API?", protocolName: "APIProtocol?"), offset: 1, length: 37, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_annotation() {
        
        let file = File(contents: """

// weaver: api <- APIProtocol
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 1, length: 29, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_annotation() {
        
        let file = File(contents: """

// weaver: movieID <= UInt
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(value: ParameterAnnotation(name: "movieID", typeName: "UInt"), offset: 1, length: 26, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_scope_annotation() {
        
        let file = File(contents: """

// weaver: api.scope = .graph
""")
        let lexer = Lexer(file, fileName: "test.swift")

        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 1, length: 29, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_custom_ref_annotation() {
        
        let file = File(contents: """

// weaver: api.customRef = true
// weaver: api.customRef = false
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(value: ConfigurationAnnotation(attribute: .customRef(value: true), target: .dependency(name: "api")), offset: 1, length: 32, line: 1))
                XCTAssertEqual(tokens[1] as? TokenBox<ConfigurationAnnotation>, TokenBox(value: ConfigurationAnnotation(attribute: .customRef(value: false), target: .dependency(name: "api")), offset: 33, length: 32, line: 2))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_an_invalid_custom_ref_annotation() {
        
        let file = File(contents: """

// weaver: api.customRef = ok
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.invalidConfigurationAttributeValue(value: "ok", expected: "true|false")
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 1, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_a_custom_ref_annotation_with_the_wrong_target() {
        
        let file = File(contents: """

// weaver: self.customRef = true
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.invalidConfigurationAttributeTarget(name: "customRef", target: .`self`)
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 1, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_true_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

// weaver: self.isIsolated = true
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(value: ConfigurationAnnotation(attribute: .isIsolated(value: true), target: .`self`), offset: 1, length: 33, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_false_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

// weaver: self.isIsolated = false
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(value: ConfigurationAnnotation(attribute: .isIsolated(value: false), target: .`self`), offset: 1, length: 34, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_an_invalid_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

// weaver: self.isIsolated = ok
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.invalidConfigurationAttributeValue(value: "ok", expected: "true|false")
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 1, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_an_empty_token_list_with_any_ignored_declaration() {
        
        let file = File(contents: """

func ignoredFunc() {
}
""")
        let lexer = Lexer(file, fileName: "test.swift")

        do {
            let tokens = try lexer.tokenize()
            XCTAssertTrue(tokens.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_an_unknown_configuration_attribute() {
        
        let file = File(contents: """

// weaver: self.fakeAttribute = true
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.unknownConfigurationAttribute(name: "fakeAttribute")
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 1, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_an_invalid_annotation() {
        
        let file = File(contents: """

final class MyService {
  let dependencies: DependencyResolver

  // weaver: api = API <-- APIProtocol
  // weaver: api.scope = .graph

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }

  func doSomething() {
    otherService.doSomething(in: api).then { result in
      if let session = self.session {
        router.redirectSomewhereWeAreLoggedIn()
      } else {
        router.redirectSomewhereWeAreLoggedOut()
      }
    }
  }
}
""")
        let lexer = Lexer(file, fileName: "test.swift")

        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.invalidAnnotation("weaver: api = API <-- APIProtocol")
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 4, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_a_scope_rule() {
        
        let file = File(contents: """

final class MyService {
  let dependencies: DependencyResolver

  // weaver: api = API <- APIProtocol
  // weaver: api.scope = .thisScopeDoesNotExists

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }

  func doSomething() {
    otherService.doSomething(in: api).then { result in
      if let session = self.session {
        router.redirectSomewhereWeAreLoggedIn()
      } else {
        router.redirectSomewhereWeAreLoggedOut()
      }
    }
  }
}
""")
        let lexer = Lexer(file, fileName: "test.swift")

        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            let underlyingError = TokenError.invalidScope("thisScopeDoesNotExists")
            XCTAssertEqual(error, LexerError.invalidAnnotation(FileLocation(line: 5, file: "test.swift"), underlyingError: underlyingError))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_weaver_import_declaration() {
        
        let file = File(contents: """

// weaver: import API
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ImportDeclaration>, TokenBox(value: ImportDeclaration(moduleName: "API"), offset: 1, length: 21, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_import_declaration() {
        
        let file = File(contents: """

import API
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ImportDeclaration>, TokenBox(value: ImportDeclaration(moduleName: "API"), offset: 1, length: 10, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
