//
//  InspectorTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 3/11/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import BeaverDICodeGen

final class InspectorTests: XCTestCase {
    
    func testInspectorShouldBuildAValidGraph() {
        
        let file = File(contents: """
// beaverdi: parent = MainDependencyResolver
final class API {
  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
}

// beaverdi: parent = MainDependencyResolver
final class SessionManager {
  // beaverdi: api = API <- APIProtocol
}

// beaverdi: parent = MainDependencyResolver
final class Router {
  // beaverdi: api = API <- APIProtocol
}

// beaverdi: parent = MainDependencyResolver
final class LoginController {
  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
}

// beaverdi: parent = MainDependencyResolver
final class App {
  // beaverdi: router = Router <- RouterProtocol
  // beaverdi: router.scope = .container

  // beaverdi: sessionManager = SessionManager <- SessionManagerProtocol
  // beaverdi: sessionManager.scope = .container

  // beaverdi: api = API <- APIProtocol
  // beaverdi: api.scope = .container
  
  // beaverdi: loginController = LoginController
  // beaverdi: loginController.scope = .container
}
""")
        
        do {
            let lexer = Lexer(file)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens)
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])

            XCTAssertTrue(inspector.isValid)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
