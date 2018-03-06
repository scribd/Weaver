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

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router = Router
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
        
        XCTAssertEqual(tokens.count, 16)
        guard tokens.count == 16 else { return }

        XCTAssertEqual(tokens[0] as? TokenBox<ParentResolverAnnotation>, TokenBox(value: ParentResolverAnnotation(typeName: "MainDependencyResolver"), offset: 0, length: 45, line: 0))
        XCTAssertEqual(tokens[1] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyService"), offset: 70, length: 482, line: 2))
        XCTAssertEqual(tokens[2] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 90, length: 36, line: 3))
        XCTAssertEqual(tokens[3] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "api", typeName: "API", protocolName: "APIProtocol"), offset: 130, length: 38, line: 5))
        XCTAssertEqual(tokens[4] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 170, length: 32, line: 6))
        XCTAssertEqual(tokens[5] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "router", typeName: "Router", protocolName: nil), offset: 205, length: 29, line: 8))
        XCTAssertEqual(tokens[6] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "router", scope: .parent), offset: 236, length: 36, line: 9))
        XCTAssertEqual(tokens[7] as? TokenBox<ParentResolverAnnotation>, TokenBox(value: ParentResolverAnnotation(typeName: "MyServiceDependencyResolver"), offset: 275, length: 50, line: 11))
        XCTAssertEqual(tokens[8] as? TokenBox<InjectableType>, TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 333, length: 130, line: 12))
        XCTAssertEqual(tokens[9] as? TokenBox<RegisterAnnotation>, TokenBox(value: RegisterAnnotation(name: "session", typeName: "Session?", protocolName: "SessionProtocol?"), offset: 364, length: 52, line: 14))
        XCTAssertEqual(tokens[10] as? TokenBox<ScopeAnnotation>, TokenBox(value: ScopeAnnotation(name: "session", scope: .container), offset: 420, length: 40, line: 15))
        XCTAssertEqual(tokens[11] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 462, length: 1, line: 16))
        XCTAssertEqual(tokens[12] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 467, length: 83, line: 18))
        XCTAssertEqual(tokens[13] as? TokenBox<AnyDeclaration>, TokenBox(value: AnyDeclaration(), offset: 472, length: 34, line: 18))
        XCTAssertEqual(tokens[14] as? TokenBox<EndOfAnyDeclaration>, TokenBox(value: EndOfAnyDeclaration(), offset: 549, length: 1, line: 20))
        XCTAssertEqual(tokens[15] as? TokenBox<EndOfInjectableType>, TokenBox(value: EndOfInjectableType(), offset: 551, length: 1, line: 21))
    }
    
    func testTokenizerShouldThrowAnErrorWithTheRightLineAndContentOnARegisterRule() {
        
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
        } catch Lexer.Error.invalidAnnotation(let line, .invalidAnnotation(let content)) {
            XCTAssertEqual(line, 4)
            XCTAssertEqual(content, "beaverdi: api = API <-- APIProtocol")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func testTokenizerShouldThrowAnErrorWithTheRightLineAndContentOnAScopeRule() {
        
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
        } catch Lexer.Error.invalidAnnotation(let line, .invalidScope(let scope)) {
            XCTAssertEqual(line, 5)
            XCTAssertEqual(scope, "thisScopeDoesNotExists")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
}

