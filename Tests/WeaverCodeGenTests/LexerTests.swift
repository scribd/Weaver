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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService")),
                    offset: 7, length: 19, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 25, length: 1, line: 2)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService")),
                    offset: 7, length: 57, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyEmbeddedService")),
                    offset: 33, length: 29, line: 2)
                )
                XCTAssertEqual(tokens[2] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 61, length: 1, line: 3)
                )
                XCTAssertEqual(tokens[3] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 63, length: 1, line: 4)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService"), accessLevel: .public),
                    offset: 14, length: 19, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 32, length: 1, line: 2)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_open_type_declaration() {
        
        let file = File(contents: """

open final class MyService {
}
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService"), accessLevel: .open),
                    offset: 12, length: 19, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 30, length: 1, line: 2)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService"), accessLevel: .internal),
                    offset: 16, length: 19, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 34, length: 1, line: 2)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "MyService"), doesSupportObjc: true),
                    offset: 1, length: 58, line: 1)
                )
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(
                    value: EndOfInjectableType(),
                    offset: 58, length: 1, line: 2)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(
                        name: "api",
                        type: SwiftType(name: "API"),
                        protocolType: SwiftType(name: "APIProtocol")
                ), offset: 1, length: 35, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(
                        name: "api",
                        type: SwiftType(name: "API"),
                        protocolType: nil
                ), offset: 1, length: 20, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(
                        name: "api",
                        type: SwiftType(name: "API", isOptional: true),
                        protocolType: SwiftType(name: "APIProtocol", isOptional: true)
                ), offset: 1, length: 37, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_annotation_with_generic_types() {
        
        let file = File(contents: """

// weaver: request = Request<T, P> <- APIRequest<T, P>
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(
                        name: "request",
                        type: SwiftType(name: "Request", genericNames: ["T", "P"]),
                        protocolType: SwiftType(name: "APIRequest", genericNames: ["T", "P"])
                ), offset: 1, length: 54, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_annotation_with_generic_and_optional_types() {
        
        let file = File(contents: """

// weaver: request = Request<T, P>? <- APIRequest<T, P>?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(
                        name: "request",
                        type: SwiftType(name: "Request", genericNames: ["T", "P"], isOptional: true),
                        protocolType: SwiftType(name: "APIRequest", genericNames: ["T", "P"], isOptional: true)
                ), offset: 1, length: 56, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(
                    value: ReferenceAnnotation(name: "api", type: SwiftType(name: "APIProtocol")),
                    offset: 1, length: 29, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_annotation_with_an_optional_type() {
        
        let file = File(contents: """

// weaver: api <- APIProtocol?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(
                    value: ReferenceAnnotation(name: "api", type: SwiftType(name: "APIProtocol", isOptional: true)),
                    offset: 1, length: 30, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_annotation_with_a_generic_type() {
        
        let file = File(contents: """

// weaver: request <- Request<T, P>
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(
                    value: ReferenceAnnotation(
                        name: "request",
                        type: SwiftType(name: "Request", genericNames: ["T", "P"])),
                    offset: 1, length: 35, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_annotation_with_a_generic_optional_type() {
        
        let file = File(contents: """

// weaver: request <- Request<T, P>?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(
                    value: ReferenceAnnotation(
                        name: "request",
                        type: SwiftType(name: "Request", genericNames: ["T", "P"], isOptional: true)
                ), offset: 1, length: 36, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(
                    value: ParameterAnnotation(name: "movieID", type: SwiftType(name: "UInt")),
                    offset: 1, length: 26, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_annotation_with_an_optional_type() {
        
        let file = File(contents: """

// weaver: movieID <= UInt?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(
                    value: ParameterAnnotation(name: "movieID", type: SwiftType(name: "UInt", isOptional: true)),
                    offset: 1, length: 27, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_annotation_with_a_generaic_type() {
        
        let file = File(contents: """

// weaver: request <= Request<T, P>
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(
                    value: ParameterAnnotation(name: "request", type: SwiftType(name: "Request", genericNames: ["T", "P"])),
                    offset: 1, length: 35, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_annotation_with_a_generaic_optional_type() {
        
        let file = File(contents: """

// weaver: request <= Request<T, P>?
""")
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(
                    value: ParameterAnnotation(
                        name: "request",
                        type: SwiftType(name: "Request", genericNames: ["T", "P"], isOptional: true)
                ), offset: 1, length: 36, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(
                    value: ConfigurationAnnotation(attribute: .scope(value: .graph), target: .dependency(name: "api")),
                    offset: 1, length: 29, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_custom_builder_annotation() {
        
        let file = File(contents: """

// weaver: api.builder = make
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(
                    value: ConfigurationAnnotation(attribute: .customBuilder(value: "make"), target: .dependency(name: "api")),
                    offset: 1, length: 29, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
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
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(
                    value: ConfigurationAnnotation(attribute: .isIsolated(value: true), target: .`self`),
                    offset: 1, length: 33, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<ConfigurationAnnotation>, TokenBox(
                    value: ConfigurationAnnotation(attribute: .isIsolated(value: false), target: .`self`),
                    offset: 1, length: 34, line: 1)
                )
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
            let underlyingError = TokenError.invalidConfigurationAttributeValue(value: ".thisScopeDoesNotExists", expected: "transient|graph|weak|container")
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
                XCTAssertEqual(tokens[0] as? TokenBox<ImportDeclaration>, TokenBox(
                    value: ImportDeclaration(moduleName: "API"),
                    offset: 1, length: 21, line: 1)
                )
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
                XCTAssertEqual(tokens[0] as? TokenBox<ImportDeclaration>, TokenBox(
                    value: ImportDeclaration(moduleName: "API"),
                    offset: 1, length: 10, line: 1)
                )
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_generic_type_declaration() {
        
        let file = File(contents: """

final class MovieManager {
    // weaver: logger = Logger<String>
}
final class Logger<T> {
    // weaver: domain <= T
}
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 6 {
                XCTAssertEqual(tokens[3] as? TokenBox<InjectableType>, TokenBox(
                    value: InjectableType(type: SwiftType(name: "Logger", genericNames: ["T"])),
                    offset: 75, length: 46, line: 4
                ))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_array_type_token_declaration() {
        
        let file = File(contents: """

final class MovieManager {
    // weaver: array = [String]
}
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(name: "array", type: SwiftType(name: "Array", genericNames: ["String"], isOptional: false), protocolType: nil),
                    offset: 32, length: 28, line: 2
                ))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_optional_array_type_token_declaration() {
        
        let file = File(contents: """

final class MovieManager {
    // weaver: array = [ String? ]?
}
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(name: "array", type: SwiftType(name: "Array", genericNames: ["String?"], isOptional: true), protocolType: nil),
                    offset: 32, length: 32, line: 2
                ))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_dict_type_token_declaration() {
        
        let file = File(contents: """

final class MovieManager {
    // weaver: dict = [ String : Int ]
}
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(name: "dict", type: SwiftType(name: "Dictionary", genericNames: ["String", "Int"], isOptional: false), protocolType: nil),
                    offset: 32, length: 35, line: 2
                ))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_optional_dict_type_token_declaration() {
        
        let file = File(contents: """

final class MovieManager {
    // weaver: dict = [String?:Int?]?
}
""")
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1] as? TokenBox<RegisterAnnotation>, TokenBox(
                    value: RegisterAnnotation(name: "dict", type: SwiftType(name: "Dictionary", genericNames: ["String?", "Int?"], isOptional: true), protocolType: nil),
                    offset: 32, length: 34, line: 2
                ))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
