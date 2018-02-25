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
        let tokens = try! lexer.tokenize()
        
        XCTAssertEqual(tokens.count, 12)
        if tokens.count == 12 {
            XCTAssertEqual(tokens[0], Token(type: .annotation(.parentResolver(type: "MainDependencyResolver")), offset: 0, length: 45, line: 0))
            XCTAssertEqual(tokens[1], Token(type: .type, offset: 51, length: 721, line: 1))
            XCTAssertEqual(tokens[2], Token(type: .annotation(.register(name: "api", type: "APIProtocol")), offset: 111, length: 32, line: 4))
            XCTAssertEqual(tokens[3], Token(type: .annotation(.scope(name: "api", scope: .graph)), offset: 145, length: 32, line: 5))
            XCTAssertEqual(tokens[4], Token(type: .annotation(.register(name: "router", type: "RouterProtocol")), offset: 180, length: 38, line: 7))
            XCTAssertEqual(tokens[5], Token(type: .annotation(.scope(name: "router", scope: .parent)), offset: 220, length: 36, line: 8))
            XCTAssertEqual(tokens[6], Token(type: .annotation(.parentResolver(type: "MyServiceDependencyResolver")), offset: 259, length: 50, line: 10))
            XCTAssertEqual(tokens[7], Token(type: .type, offset: 317, length: 119, line: 11))
            XCTAssertEqual(tokens[8], Token(type: .annotation(.register(name: "session", type: "SessionProtocol?")), offset: 348, length: 41, line: 13))
            XCTAssertEqual(tokens[9], Token(type: .annotation(.scope(name: "session", scope: .container)), offset: 393, length: 40, line: 14))
            XCTAssertEqual(tokens[10], Token(type: .endOfType, offset: 435, length: 1, line: 15))
            XCTAssertEqual(tokens[11], Token(type: .endOfType, offset: 771, length: 1, line: 30))
        }
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

