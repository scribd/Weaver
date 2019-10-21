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
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "sessionManager",
                                                                                            type: nil),
                                                                        underlyingError: .unresolvableDependency(history: [
                                                                            InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 4, file: "test.swift"),
                                                                                                                                                  name: "sessionManager",
                                                                                                                                                  type: SwiftType(name: "App")))
                                                                            ])))
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
            let underlyingError = InspectorAnalysisError.cyclicDependency(history: [
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 10, file: "test.swift"), type: SwiftType(name: "SessionManager")), stepCount: 0),
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 0, file: "test.swift"), type: SwiftType(name: "API")), stepCount: 1),
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 5, file: "test.swift"), type: SwiftType(name: "Session")), stepCount: 2)
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 6, file: "test.swift"),
                                                                                            name: "sessionManager",
                                                                                            type: SwiftType(name: "SessionManager")),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_inspector_should_build_a_valid_dependency_graph_with_an_unresolvable_ref_with_custom_builder_set_to_true() {
        let file = File(contents: """
final class API {
    // weaver: api <- APIProtocol
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
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_of_a_custom_builder_not_shared_with_children() {
        let file = File(contents: """
final class AppDelegate {
    // weaver: appDelegate <- AppDelegateProtocol
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
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.foundUnaccessibleDependency(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                               name: "appDelegate",
                                                                                               type: nil))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 10, file: "test.swift"),
                                                                                            name: "appDelegate",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
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
    
    func test_inspector_should_build_an_invalid_dependency_graph_because_of_an_incorrectly_named_reference() {
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
            let linker = try Linker(syntaxTrees: [syntaxTree])
            let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
            
            try inspector.validate()
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 0, file: "test.swift"),
                                                                                      name: "viewController3",
                                                                                      type: SwiftType(name: "AppDelegate")))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 14, file: "test.swift"),
                                                                                            name: "viewController3",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
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
            let underlyingError = InspectorAnalysisError.isolatedResolverCannotHaveReferents(type: SwiftType(name: "HomeViewController"), referents: [
                PrintableResolver(fileLocation: FileLocation(line: 0, file: "test.swift"), type: SwiftType(name: "AppDelegate"))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 34, file: "test.swift"),
                                                                                            name: "movieAPI",
                                                                                            type: SwiftType(name: "MovieAPI")),
                                                                        underlyingError: underlyingError))
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
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 5, file: "test.swift"),
                                                                                      name: "urlSession",
                                                                                      type: SwiftType(name: "HomeViewController"))),
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 0, file: "test.swift"),
                                                                                      name: "urlSession",
                                                                                      type: SwiftType(name: "AppDelegate")))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 11, file: "test.swift"),
                                                                                            name: "urlSession",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
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
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "movieManager",
                                                                                            type: nil),
                                                                        underlyingError: InspectorAnalysisError.unresolvableDependency(history: [])))
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
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "logger",
                                                                                            type: nil),
                                                                        underlyingError: InspectorAnalysisError.unresolvableDependency(history: [])))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
