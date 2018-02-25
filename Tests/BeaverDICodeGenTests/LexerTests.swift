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
    
    func testTokenizeShouldProvideAFullTokenList() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
// regular comment
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api -> APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router -> RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver
  final class MyEmbeddedService {

    // beaverdi: session -> SessionProtocol?
    // beaverdi: session.scope = .container
  }

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}
""")
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        
        XCTAssertEqual(tokens.count, 16)
        guard tokens.count == 16 else { return }

        XCTAssertEqual(tokens[0], Token(type: .annotation(.parentResolver(type: "MainDependencyResolver")), offset: 0, length: 45, line: 0))
        XCTAssertEqual(tokens[1], Token(type: .injectableType, offset: 70, length: 474, line: 2))
        XCTAssertEqual(tokens[2], Token(type: .anyDeclaration, offset: 90, length: 36, line: 3))
        XCTAssertEqual(tokens[3], Token(type: .annotation(.register(name: "api", type: "APIProtocol")), offset: 130, length: 32, line: 5))
        XCTAssertEqual(tokens[4], Token(type: .annotation(.scope(name: "api", scope: .graph)), offset: 164, length: 32, line: 6))
        XCTAssertEqual(tokens[5], Token(type: .annotation(.register(name: "router", type: "RouterProtocol")), offset: 199, length: 38, line: 8))
        XCTAssertEqual(tokens[7], Token(type: .annotation(.parentResolver(type: "MyServiceDependencyResolver")), offset: 278, length: 50, line: 11))
        XCTAssertEqual(tokens[8], Token(type: .injectableType, offset: 336, length: 119, line: 12))
        XCTAssertEqual(tokens[9], Token(type: .annotation(.register(name: "session", type: "SessionProtocol?")), offset: 367, length: 41, line: 14))
        XCTAssertEqual(tokens[10], Token(type: .annotation(.scope(name: "session", scope: .container)), offset: 412, length: 40, line: 15))
        XCTAssertEqual(tokens[11], Token(type: .endOfInjectableType, offset: 454, length: 1, line: 16))
        XCTAssertEqual(tokens[12], Token(type: .anyDeclaration, offset: 459, length: 83, line: 18))
        XCTAssertEqual(tokens[13], Token(type: .anyDeclaration, offset: 464, length: 34, line: 18))
        XCTAssertEqual(tokens[14], Token(type: .endOfAnyDeclaration, offset: 541, length: 1, line: 20))
        XCTAssertEqual(tokens[15], Token(type: .endOfInjectableType, offset: 543, length: 1, line: 21))
    }
    
    func testTokenizerShouldThrowAnErrorWithTheRightLineAndContentOnARegisterRule() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api --> APIProtocol
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
        } catch Lexer.Error.invalidAnnotation(let line, .invalidAnnotation(let content)) {
            XCTAssertEqual(line, 4)
            XCTAssertEqual(content, "beaverdi: api --> APIProtocol")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func testTokenizerShouldThrowAnErrorWithTheRightLineAndContentOnAScopeRule() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api -> APIProtocol
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
        } catch Lexer.Error.invalidAnnotation(let line, .invalidScope(let scope)) {
            XCTAssertEqual(line, 5)
            XCTAssertEqual(scope, "thisScopeDoesNotExists")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
}

