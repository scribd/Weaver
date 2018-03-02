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

class AnotherService {
    // This class is ignored
}
""")

        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)

        let syntaxTree = try? parser.parse()
        
        let expected = Expr.file(types: [.typeDeclaration(TokenBox(value: InjectableType(name: "MyService"), offset: 51, length: 474, line: 1),
                                                          parentResolver: TokenBox(value: ParentResolverAnnotation(type: "MainDependencyResolver"), offset: 0, length: 45, line: 0),
                                                          children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "api", type: "APIProtocol"), offset: 111, length: 32, line: 4)),
                                                                     .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "api", scope: .graph), offset: 145, length: 32, line: 5)),
                                                                     .registerAnnotation(TokenBox(value: RegisterAnnotation(name: "router", type: "RouterProtocol"), offset: 180, length: 38, line: 7)),
                                                                     .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "router", scope: .parent), offset: 220, length: 36, line: 8)),
                                                                     .typeDeclaration(TokenBox(value: InjectableType(name: "MyEmbeddedService"), offset: 317, length: 119, line: 11),
                                                                                      parentResolver: TokenBox(value: ParentResolverAnnotation(type: "MyServiceDependencyResolver"), offset: 259, length: 50, line: 10),
                                                                                      children: [.registerAnnotation(TokenBox(value: RegisterAnnotation(name: "session", type: "SessionProtocol?"), offset: 348, length: 41, line: 13)),
                                                                                                 .scopeAnnotation(TokenBox(value: ScopeAnnotation(name: "session", scope: .container), offset: 393, length: 40, line: 14))])])])
        
        XCTAssertEqual(syntaxTree, expected)
    }
    
    func testParserShouldReturnAnEmptyFileWhenThereIsNoDeclarationInTheFile() {
        
        let file = File(contents: """
class Test {
}
""")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        let syntaxTree = try? parser.parse()
        
        XCTAssertEqual(syntaxTree, .file(types: []))
    }
    
    func testParserShouldReturnAnEmptyFileWhenTheFileIsEmpty() {
        
        let file = File(contents: "")
        
        let lexer = Lexer(file)
        let tokens = try! lexer.tokenize()
        let parser = Parser(tokens)
        
        let syntaxTree = try? parser.parse()
        
        XCTAssertEqual(syntaxTree, .file(types: []))
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
    
    func testParserShouldGenerateASyntaxErrorWhenADependencyIsDeclaredInANonInjectableType() {
        
        let file = File(contents: """
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
            XCTAssertEqual(error as? Parser.Error, .unexpectedToken)
        }
    }
    
    func testParserShouldGenerateASyntaxErrorWhenADependencyIsDeclaredOutsideOfAType() {
        
        let file = File(contents: """
  // beaverdi: api -> APIProtocol
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
}
