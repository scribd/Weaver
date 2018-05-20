//
//  InspectorTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 3/11/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class InspectorTests: XCTestCase {
    
    func test_inspector_should_build_a_valid_graph() {
        
        let file = File(contents: """
final class API {
  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
}

final class SessionManager {
}

final class Router {
  // weaver: api <- APIProtocol
}

final class LoginController {
  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
}

final class App {
  // weaver: router = Router <- RouterProtocol
  // weaver: router.scope = .container

  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
  // weaver: sessionManager.scope = .container

  // weaver: api = API <- APIProtocol
  // weaver: api.scope = .container
  
  // weaver: loginController = LoginController
  // weaver: loginController.scope = .container
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])

            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_an_unresolvable_dependency() {
        let file = File(contents: """
final class API {
  // weaver: sessionManager <- SessionManagerProtocol
}

final class App {
  // weaver: api = API
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 1,
                                                file: "test.swift",
                                                dependencyName: "sessionManager",
                                                typeName: nil,
                                                underlyingError: .unresolvableDependency(history: [
                                                    .dependencyNotFound(line: 4, file: "test.swift", name: "sessionManager", typeName: "App")
                                                    ])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_a_cyclic_dependency() {
        let file = File(contents: """
final class API {
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container

    // weaver: sessionManager1 = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager1.scope = .transient
}

final class SessionManager {
    // weaver: api = API <- APIProtocol
    // weaver: api.scope = .weak
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 9,
                                                file: "test.swift",
                                                dependencyName: "sessionManager1",
                                                typeName: "SessionManager",
                                                underlyingError: .cyclicDependency(history: [
                                                    .triedToBuildType(line: 13, file: "test.swift", typeName: "SessionManager", stepCount: 0),
                                                    .triedToBuildType(line: 0, file: "test.swift", typeName: "API", stepCount: 1),
                                                    .triedToBuildType(line: 5, file: "test.swift", typeName: "Session", stepCount: 2)
                                                    ])))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_inspector_should_build_a_valid_graph_with_a_lazy_loaded_dependency_cycle() {
        let file = File(contents: """
final class API {
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container

    // weaver: sessionManager1 = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager1.scope = .container
}

final class SessionManager {
    // weaver: api = API <- APIProtocol
    // weaver: api.scope = .weak
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_an_unresolvable_ref_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class API {
    // weaver: api <- APIProtocol
    // weaver: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_an_unbuildable_dependency_with_custom_ref_set_to_true() {
        let file = File(contents: """
final class API {
    // weaver: api = API <- APIProtocol
    // weaver: api.customRef = true
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_a_more_complex_custom_ref_resolution() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: appDelegate = AppDelegateProtocol
    // weaver: appDelegate.scope = .container
    // weaver: appDelegate.customRef = true
    
    // weaver: viewController = ViewController
    // weaver: viewController.scope = .container
    // weaver: viewController.customRef = true
}

final class ViewController {
    // weaver: appDelegate <- AppDelegateProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_a_custom_ref_not_shared_with_children() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: appDelegate <- AppDelegateProtocol
    // weaver: appDelegate.customRef = true
    
    // weaver: viewController = ViewController
    // weaver: viewController.scope = .container
    // weaver: viewController.customRef = true
}

final class ViewController {
    // weaver: appDelegate <- AppDelegateProtocol
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 10,
                                                file: "test.swift",
                                                dependencyName: "appDelegate",
                                                typeName: nil,
                                                underlyingError: .unresolvableDependency(history: [.foundUnaccessibleDependency(line: 1, file: "test.swift", name: "appDelegate", typeName: nil)])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_two_references_of_the_same_type() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: viewController1 = ViewController1 <- UIViewController
    // weaver: viewController1.scope = .container

    // weaver: viewController2 = ViewController2 <- UIViewController
    // weaver: viewController2.scope = .container

    // weaver: coordinator = Coordinator
    // weaver: coordinator.scope = .container
}

final class ViewController1: UIViewController {
    // weaver: viewController2 <- UIViewController
}

final class Coordinator {
    // weaver: viewController2 <- UIViewController
    // weaver: viewController1 <- UIViewController
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_because_of_an_incorrectly_named_reference() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: viewController1 = ViewController1 <- UIViewController
    // weaver: viewController1.scope = .container

    // weaver: viewController2 = ViewController2 <- UIViewController
    // weaver: viewController2.scope = .container

    // weaver: coordinator = Coordinator
    // weaver: coordinator.scope = .container
}

final class Coordinator {
    // weaver: viewController1 <- UIViewController
    // weaver: viewController2 <- UIViewController
    // weaver: viewController3 <- UIViewController
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 14,
                                                file: "test.swift",
                                                dependencyName: "viewController3",
                                                typeName: nil,
                                                underlyingError: .unresolvableDependency(history: [
                                                    .dependencyNotFound(line: 0, file: "test.swift", name: "viewController3", typeName: "AppDelegate")
                                                    ])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_references_on_several_levels() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.customRef = true
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_graph_with_two_isolated_objects() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.customRef = true
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_with_an_object_flagged_as_isolated_with_a_non_isolated_dependent() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.customRef = true
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container

    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 34,
                                                file: "test.swift",
                                                dependencyName: "movieAPI",
                                                typeName: "MovieAPI",
                                                underlyingError: .isolatedResolverCannotHaveReferents(typeName: "HomeViewController",
                                                                                                      referents: [InspectorAnalysisResolver(line: 0, file: "test.swift", typeName: "AppDelegate")])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_graph_with_an_unresolvable_dependency_on_two_levels() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .container
}

final class MovieViewController: UIViewController {
    // weaver: urlSession <- URLSession
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let inspector = try Inspector(syntaxTrees: [syntaxTree])
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, .invalidGraph(line: 11,
                                                file: "test.swift",
                                                dependencyName: "urlSession",
                                                typeName: nil,
                                                underlyingError: .unresolvableDependency(history: [.dependencyNotFound(line: 5, file: "test.swift", name: "urlSession", typeName: "HomeViewController"),
                                                                                                   .dependencyNotFound(line: 0, file: "test.swift", name: "urlSession", typeName: "AppDelegate")])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
}
