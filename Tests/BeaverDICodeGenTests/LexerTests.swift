//
//  LexerTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import BeaverDICodeGen

final class LexerTests: XCTestCase {
    
    func test_tokenize_should_provide_a_full_token_list() {
        
        let file = File(contents: """
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router
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
        
        XCTAssertEqual(tokens.count, 14)
        guard tokens.count == 14 else { return }

        XCTAssertEqual(tokens[0] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService"), offset: 6, length: 430, line: 0))
        XCTAssertEqual(tokens[1] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 26, length: 36, line: 1))
        XCTAssertEqual(tokens[2] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 66, length: 38, line: 3))
        XCTAssertEqual(tokens[3] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 106, length: 32, line: 4))
        XCTAssertEqual(tokens[4] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "router", typeName: "Router", protocolName: nil), offset: 141, length: 29, line: 6))
        XCTAssertEqual(tokens[5] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "router", scope: .parent), offset: 172, length: 36, line: 7))
        XCTAssertEqual(tokens[6] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 217, length: 130, line: 9))
        XCTAssertEqual(tokens[7] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session?", protocolName: "SessionProtocol?"), offset: 248, length: 52, line: 11))
        XCTAssertEqual(tokens[8] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "session", scope: .container), offset: 304, length: 40, line: 12))
        XCTAssertEqual(tokens[9] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 346, length: 1, line: 13))
        XCTAssertEqual(tokens[10] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 351, length: 83, line: 15))
        XCTAssertEqual(tokens[11] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 356, length: 34, line: 15))
        XCTAssertEqual(tokens[12] as? TokenBox<EndOfAnyDeclaration>, TokenBox(value: EndOfAnyDeclaration(), offset: 433, length: 1, line: 17))
        XCTAssertEqual(tokens[13] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 435, length: 1, line: 18))
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_a_register_rule() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <-- APIProtocol
  // beaverdi: api.scope = .graph

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
        let lexer = Lexer(file)

        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch LexerError.invalidAnnotation(let line, .invalidAnnotation(let content)) {
            XCTAssertEqual(line, 4)
            XCTAssertEqual(content, "beaverdi: api = API <-- APIProtocol")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_a_scope_rule() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .thisScopeDoesNotExists

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
        let lexer = Lexer(file)
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch LexerError.invalidAnnotation(let line, .invalidScope(let scope)) {
            XCTAssertEqual(line, 5)
            XCTAssertEqual(scope, "thisScopeDoesNotExists")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
}

