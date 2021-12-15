//
//  RuntimeTreeInspectorTests.swift
//  WeaverCodeGenTests
//
//  Created by Stephane Magne on 12/15/21.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class RuntimeTreeInspectorTests: XCTestCase {

    func test_tree_inspector_should_validate_a_dependency_graph_with_resolvable_container_dependencies_as_uptree_parameters() {

        let file = File(contents: """
            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class ViewController1: UIViewController {
                // weaver: coordinator <= Coordinator

                // weaver: viewController2 = ViewController2
                // weaver: viewController2.scope = .transient
            }

            final class ViewController2: UIViewController {
                // weaver: coordinator <- Coordinator
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

    func test_tree_inspector_should_not_validate_a_dependency_graph_with_unresolvable_container_dependencies_as_uptree_parameters() {

        let file = File(contents: """
            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient

                // weaver: viewController1 = ViewController1 <- UIViewController
                // weaver: viewController1.scope = .transient

                // weaver: viewController3 = ViewController3 <- UIViewController
                // weaver: viewController3.scope = .transient
            }

            final class ViewController1: UIViewController {
                // weaver: coordinator <= Coordinator

                // weaver: viewController2 = ViewController2 <- UIViewController
                // weaver: viewController2.scope = .transient
            }

            final class ViewController2: UIViewController {
                // weaver: coordinator <- Coordinator
            }

            final class ViewController3: UIViewController {
                // weaver: coordinator <- Coordinator
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
            print("error = \(error)")
            XCTAssertEqual(error.description, """
            test.swift:28: error: Invalid dependency: 'coordinator: Coordinator'. Dependency cannot be resolved.
            test.swift:28: warning: Step 0: Tried to resolve dependency 'coordinator' in type 'ViewController3'.
            test.swift:28: warning: Step 1: Tried to resolve dependency 'coordinator' in type 'AppDelegate'.
            test.swift:28: error: Dependency 'coordinator' cannot declare parameters and be registered with a container scope. This must either have no parameters or itself be injected as a parameter to a parent depdenceny.
            """)
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
}
