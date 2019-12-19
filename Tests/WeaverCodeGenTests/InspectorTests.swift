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
    
    func test_inspector_should_build_a_valid_dependency_graph() {
        
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_of_an_unresolvable_dependency() {
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:2: error: Invalid dependency: 'sessionManager: SessionManagerProtocol'. Dependency cannot be resolved.
test.swift:1: warning: Could not find the dependency 'sessionManager' in 'API'. You may want to register it here to solve this issue.
test.swift:5: warning: Could not find the dependency 'sessionManager' in 'App'. You may want to register it here to solve this issue.
""")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_of_a_cyclic_dependency() {
        let file = File(contents: """
final class API {
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:2: error: Invalid dependency: 'session: Session <- SessionProtocol'. Detected a cyclic dependency.
test.swift:6: warning: Step 0: Tried to build type 'Session'.
test.swift:11: warning: Step 1: Tried to build type 'SessionManager'.
test.swift:1: warning: Step 2: Tried to build type 'API'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_cyclic_dependency_graph_with_a_self_reference() {
        let file = File(contents: """
final class API {
    // weaver: api <- APIProtocol
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_inspector_should_build_a_valid_dependency_graph_with_an_unbuildable_dependency_with_custom_builder_set_to_true() {
        let file = File(contents: """
final class API {
    // weaver: api = API <- APIProtocol
    // weaver: api.builder = API.make
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_a_more_complex_custom_builder_resolution() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: appDelegate = AppDelegateProtocol
    // weaver: appDelegate.scope = .container
    // weaver: appDelegate.builder = AppDelegate.make
    
    // weaver: viewController = ViewController
    // weaver: viewController.scope = .container
    // weaver: viewController.builder = ViewController.make
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_two_references_of_the_same_type() {
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_references_on_several_levels() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependencyGraph_with_two_isolated_objects() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_an_object_flagged_as_isolated_with_a_non_isolated_dependent() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:19: error: Invalid dependency: 'movieManager: MovieManaging'. This type is flagged as isolated. It cannot have any connected referent.
test.swift:1: error: 'AppDelegate' cannot depend on 'HomeViewController' because it is flagged as 'isolated'. You may want to set 'HomeViewController.isIsolated' to 'false'.
""")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_an_unresolvable_dependency_on_two_levels() {
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:12: error: Invalid dependency: 'urlSession: URLSession'. Dependency cannot be resolved.
test.swift:11: warning: Could not find the dependency 'urlSession' in 'MovieViewController'. You may want to register it here to solve this issue.
test.swift:6: warning: Could not find the dependency 'urlSession' in 'HomeViewController'. You may want to register it here to solve this issue.
test.swift:1: warning: Could not find the dependency 'urlSession' in 'AppDelegate'. You may want to register it here to solve this issue.
""")
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_a_public_type_with_no_dependents() {
        let file = File(contents: """
public final class MovieViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_an_internal_type_with_no_dependents() {
        let file = File(contents: """
final class MovieViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:2: error: Invalid dependency: 'movieManager: MovieManaging'. Dependency cannot be resolved.
test.swift:1: warning: Type 'MovieViewController' doesn't seem to be attached to the dependency graph. You might have to use `self.isIsolated = true` or register it somewhere.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_an_internal_type_accessing_to_a_public_reference() {
        let file = File(contents: """
public final class MovieViewController: UIViewController {
    // weaver: logger <- Logger<String>
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Logger<String>
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_an_internal_type_accessing_to_a_public_reference_with_the_wrong_type() {
        let file = File(contents: """
public final class MovieViewController: UIViewController {
    // weaver: logger <- Logger<Int>
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Logger<String>
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:7: error: Invalid dependency: 'logger: Logger<String>'. Dependency cannot be resolved.
test.swift:6: warning: Could not find the dependency 'logger' in 'MovieManager'. You may want to register it here to solve this issue.
test.swift:7: error: Dependency 'logger' has a mismatching type 'Logger<String>'.
test.swift:2: warning: Found candidate 'logger: Logger<Int>'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_by_resolving_a_dependency_from_its_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- Logging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: movieManagerLogger <- Logging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_by_resolving_a_dependency_from_its_type_on_several_levels() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- ManagerLogging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- ManagerLogging
    // weaver: api = API
}

final class API {
    // weaver: apiLogger <- ManagerLogging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_a_reference_uses_an_unknown_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- Logging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Foo
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:7: error: Invalid dependency: 'logger: Foo'. Dependency cannot be resolved.
test.swift:6: warning: Could not find the dependency 'logger' in 'MovieManager'. You may want to register it here to solve this issue.
test.swift:7: error: Dependency 'logger' has a mismatching type 'Foo'.
test.swift:2: warning: Found candidate 'logger: Logger <- Logging'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_a_reference_uses_an_implicit_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- Logging
    // weaver: logger1 = Logger1 <- Logging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: movieManagerLogger <- Logging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:8: error: Invalid dependency: 'movieManagerLogger: Logging'. Dependency cannot be resolved.
test.swift:7: warning: Could not find the dependency 'movieManagerLogger' in 'MovieManager'. You may want to register it here to solve this issue.
test.swift:8: error: Dependency 'movieManagerLogger' is implicit.
test.swift:2: warning: Found candidate 'logger'.
test.swift:3: warning: Found candidate 'logger1'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_a_reference_uses_a_concrete_type_instead_using_an_abstract_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- Logging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: movieManagerLogger <- Logger
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:7: error: Invalid dependency: 'movieManagerLogger: Logger'. Dependency cannot be resolved.
test.swift:6: warning: Could not find the dependency 'movieManagerLogger' in 'MovieManager'. You may want to register it here to solve this issue.
test.swift:7: error: Dependency 'movieManagerLogger' has a mismatching type 'Logger'.
test.swift:2: warning: Found candidate 'logger: Logger <- Logging'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_a_reference_uses_an_unknown_concrete_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- Logging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Loggers
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:7: error: Invalid dependency: 'logger: Loggers'. Dependency cannot be resolved.
test.swift:6: warning: Could not find the dependency 'logger' in 'MovieManager'. You may want to register it here to solve this issue.
test.swift:7: error: Dependency 'logger' has a mismatching type 'Loggers'.
test.swift:2: warning: Found candidate 'logger: Logger <- Logging'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_references_using_subtypes() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- ManagerLogging & UniversalLogging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: universalLogger <- UniversalLogging
    // weaver: movieLogger <- ManagerLogging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_a_reference_using_a_composite_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- ManagerLogging & UniversalLogging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: movieLogger <- ManagerLogging & UniversalLogging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_a_registration_using_an_incomplete_type() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: logger = Logger <- ManagerLogging
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: movieLogger <- ManagerLogging & UniversalLogging
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as DependencyGraphError {
            XCTAssertEqual(error.description, """
test.swift:7: error: Invalid type composition: 'ManagerLogging & UniversalLogging'.
test.swift:7: warning: Found candidates: 'logger: Logger'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_inspector_should_build_an_invalid_dependency_graph_with_a_registration_using_scope_container_on_dependency_taking_parameters() {
        let file = File(contents: """
final class MovieViewController {
    // weaver: movieManager = MovieManager
    // weaver: movieManager.scope = .container
}

final class MovieManager {
    // weaver: movieID <= Int
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:2: error: Dependency 'movieManager' cannot declare parameters and be registered with a container scope.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_of_invalid_amount_of_parameters_in_decalaration() {
        let file = File(contents: """
final class MovieViewController {
    @WeaverP2(.registration, type: MovieManager.self, scope: .transient)
    private var movieManager: MovieManager
}

final class MovieManager {
    // weaver: movieID <= Int
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error.description, """
test.swift:2: error: Invalid dependency: 'movieManager: MovieManager'. Resolver type mismatch. Expected '((Int) -> MovieManager)' but got 'MovieManager'.
""")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_property_wrapper_registration_and_reference_with_no_abstract_type() {
        let file = File(contents: """
final class MovieViewController {
    @Weaver(.reference)
    private var movieManager: MovieManager
}

final class HomeViewController {
    @Weaver(.registration)
    private var movieViewController: MovieViewController

    @Weaver(.registration, type: MovieManager.self)
    private var movieManager: MovieManager
}

final class MovieManager {
}
""")
        
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_an_invalid_dependency_graph_with_a_non_optional_weak_parameter() {
            let file = File(contents: """
    final class MovieViewController {
        @Weaver(.parameter, scope: .weak)
        private var movieManager: MovieManager
    }

    final class HomeViewController {
        @Weaver(.registration, type: MovieManager.self)
        private var movieManager: MovieManager
    }

    final class MovieManager {
    }
    """)
            
            do {
                let lexer = Lexer(file, fileName: "test.swift")
                let tokens = try lexer.tokenize()
                let parser = Parser(tokens, fileName: "test.swift")
                let syntaxTree = try parser.parse()
                let linker = try Linker(syntaxTrees: [syntaxTree])
                let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
                
                try inspector.validate()
                XCTFail("Expected error.")
            } catch let error as InspectorError {
                XCTAssertEqual(error.description, """
test.swift:2: error: Parameter 'movieManager' has to be of type optional.
""")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    
}
