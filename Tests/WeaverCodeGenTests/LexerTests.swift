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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .default), offset: 6, length: 19, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 24, length: 1, line: 1))
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .default), offset: 6, length: 57, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyEmbeddedService", accessLevel: .default), offset: 32, length: 29, line: 1))
                XCTAssertEqual(tokens[2] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 60, length: 1, line: 2))
                XCTAssertEqual(tokens[3] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 62, length: 1, line: 3))
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .public), offset: 13, length: 19, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 31, length: 1, line: 1))
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
                XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService", accessLevel: .internal), offset: 15, length: 19, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 33, length: 1, line: 1))
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 0, length: 35, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: nil), offset: 0, length: 20, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API?", protocolName: "APIProtocol?"), offset: 0, length: 37, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<ReferenceAnnotation>, TokenBox(value: ReferenceAnnotation(name: "api", typeName: "APIProtocol"), offset: 0, length: 29, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<ParameterAnnotation>, TokenBox(value: ParameterAnnotation(name: "movieID", typeName: "UInt"), offset: 0, length: 26, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 0, length: 29, line: 0))
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
                XCTAssertEqual(tokens[0] as? TokenBox<CustomRefAnnotation>, TokenBox(value: CustomRefAnnotation(name: "api", value: true), offset: 0, length: 32, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<CustomRefAnnotation>, TokenBox(value: CustomRefAnnotation(name: "api", value: false), offset: 32, length: 32, line: 1))
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
            XCTAssertEqual(error, .invalidAnnotation(line: 0, file: "test.swift", underlyingError: .invalidCustomRefValue("ok")))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_any_ignored_declaration() {
        
        let file = File(contents: """
func ignoredFunc() {
}
""")
        let lexer = Lexer(file, fileName: "test.swift")

        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 0, length: 22, line: 0))
                XCTAssertEqual(tokens[1] as? TokenBox<EndOfAnyDeclaration>, TokenBox(value: EndOfAnyDeclaration(), offset: 21, length: 1, line: 1))
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
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
            XCTAssertEqual(error, .invalidAnnotation(line: 3, file: "test.swift", underlyingError: .invalidAnnotation("weaver: api = API <-- APIProtocol")))
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
            XCTAssertEqual(error, .invalidAnnotation(line: 4,  file: "test.swift", underlyingError: .invalidScope("thisScopeDoesNotExists")))
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
}

