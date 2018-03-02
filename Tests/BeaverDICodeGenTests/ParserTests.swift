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
    
    func testParserShouldGenerateAValidSyntaxTree() {
        
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
}
""")

        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)

        let syntaxTree = try? parser.parse()
        
        let expected = Expr.typeDeclaration(Token(type: InjectableType(name: "MyService"), offset: 51, length: 474, line: 1),
                                            parentResolver: Token(type: ParentResolverAnnotation(type: "MainDependencyResolver"), offset: 0, length: 45, line: 0),
                                            children: [.registerAnnotation(Token(type: RegisterAnnotation(name: "api", type: "APIProtocol"), offset: 111, length: 32, line: 4)),
                                                       .scopeAnnotation(Token(type: ScopeAnnotation(name: "api", scope: .graph), offset: 145, length: 32, line: 5)),
                                                       .registerAnnotation(Token(type: RegisterAnnotation(name: "router", type: "RouterProtocol"), offset: 180, length: 38, line: 7)),
                                                       .scopeAnnotation(Token(type: ScopeAnnotation(name: "router", scope: .parent), offset: 220, length: 36, line: 8)),
                                                       .typeDeclaration(Token(type: InjectableType(name: "MyEmbeddedService"), offset: 317, length: 119, line: 11),
                                                                        parentResolver: Token(type: ParentResolverAnnotation(type: "MyServiceDependencyResolver"), offset: 259, length: 50, line: 10),
                                                                        children: [.registerAnnotation(Token(type: RegisterAnnotation(name: "session", type: "SessionProtocol?"), offset: 348, length: 41, line: 13)),
                                                                                   .scopeAnnotation(Token(type: ScopeAnnotation(name: "session", scope: .container), offset: 393, length: 40, line: 14))])])
        
        XCTAssertEqual(syntaxTree, expected)
    }
    
    func testParserShouldGenerateASyntaxErrorWhenAParentAnnotationIsOrfan() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api -> APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: router -> RouterProtocol
  // beaverdi: router.scope = .parent

  // beaverdi: parent = MyServiceDependencyResolver

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? Parser.Error, .unexpectedToken)
        }
    }
    
    func testParserShouldGenerateASyntaxErrorWhenAScopeIsDeclaredWithoutAnyDependencyRegistration() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

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
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? Parser.Error, .unknownDependency)
        }
    }
    
    func testParserShouldGenerateASyntaxErrorWhenAnInjectedTypeDoesNotHaveAnyDependencies() {
        
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
  }

  init(_ dependencies: DependencyResolver) {
    self.dependencies = dependencies
  }
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? Parser.Error, .missingDependency)
        }
    }
    
    func testParserShouldGenerateASyntaxErrorWhenADependencyIsDeclaredTwice() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class MyService {
  let dependencies: DependencyResolver

  // beaverdi: api -> APIProtocol
  // beaverdi: api.scope = .graph

  // beaverdi: api -> APIProtocol

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
        let parser = Parser(tokens)
        
        do {
            _ = try parser.parse()
            XCTAssertTrue(false, "An error was expected.")
        } catch {
            XCTAssertEqual(error as? Parser.Error, .depedencyDoubleDeclaration)
        }
    }
}
