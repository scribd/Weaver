//
//  LinkerTests.swift
//  WeaverCodeGenTests
//
//  Created by Stephane Magne on 11/08/22.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class LinkerTests: XCTestCase {

    func test_linker_parses_all_dependencies() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class DataManager: DataConfiguring, DataProviding {
                static let shared = DataManager()
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

            guard linker.dependencyGraph.dependencies.count == 8 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 8.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "value")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "dataConfiguration")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "dataProvider")
            XCTAssertEqual(linker.dependencyGraph.dependencies[4].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[5].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[6].dependencyName, "viewController2")
            XCTAssertEqual(linker.dependencyGraph.dependencies[7].dependencyName, "coordinator")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_linker_filters_dependencies_that_dont_match_current_platform() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient
                // weaver: coordinator.platforms = [.iOS]

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }
                // weaver: dataProvider.platforms = [.watchOS]

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class DataManager: DataConfiguring, DataProviding {
                static let shared = DataManager()
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
            let linker = try Linker(syntaxTrees: [syntaxTree], platform: .iOS)

            guard linker.dependencyGraph.dependencies.count == 7 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 7.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "value")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "dataConfiguration")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[4].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[5].dependencyName, "viewController2")
            XCTAssertEqual(linker.dependencyGraph.dependencies[6].dependencyName, "coordinator")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_linker_filters_out_entire_files_if_constructor_doesnt_match_the_current_platform() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient
                // weaver: coordinator.platforms = [.iOS]

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }
                // weaver: dataConfiguration.platforms = [.iOS, .watchOS]

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }
                // weaver: dataProvider.platforms = [.watchOS]

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class DataManager: DataConfiguring, DataProviding {
                static let shared = DataManager()
            }

            final class ViewController1: UIViewController {
                // weaver: viewController2 = ViewController2
                // weaver: viewController2.scope = .transient
            }

            final class ViewController2: UIViewController {
            }
            """)

        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree], platform: .watchOS)

            guard linker.dependencyGraph.dependencies.count == 4 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 4.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "dataConfiguration")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "dataProvider")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "viewController2")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_linker_filters_out_entire_files_if_constructor_doesnt_match_the_current_project() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient
                // weaver: coordinator.projects = [myApp]

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }
                // weaver: dataConfiguration.projects = [myApp, alternateApp]

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }
                // weaver: dataProvider.projects = [alternateApp]

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class DataManager: DataConfiguring, DataProviding {
                static let shared = DataManager()
            }

            final class ViewController1: UIViewController {
                // weaver: viewController2 = ViewController2
                // weaver: viewController2.scope = .transient
            }

            final class ViewController2: UIViewController {
            }
            """)

        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens, fileName: "test.swift")
            let syntaxTree = try parser.parse()
            let linker = try Linker(syntaxTrees: [syntaxTree], projectName: "alternateApp")

            guard linker.dependencyGraph.dependencies.count == 4 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 4.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "dataConfiguration")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "dataProvider")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "viewController2")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_linker_filters_out_entire_files_if_multiple_constructors_dont_match_the_current_platform() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {
                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }
                // weaver: dataConfiguration.platforms = [.watchOS]

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }
                // weaver: dataProvider.platforms = [.watchOS]

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient
            }

            final class DataManager: DataConfiguring, DataProviding {
                // weaver: viewController2 = ViewController2
                // weaver: viewController2.scope = .transient
            }

            final class ViewController1: UIViewController {
                // weaver: coordinator <= Coordinator
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
            let linker = try Linker(syntaxTrees: [syntaxTree], platform: .iOS)

            guard linker.dependencyGraph.dependencies.count == 5 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 5.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "value")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "coordinator")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_linker_filters_out_files_even_when_annotations_are_not_contiguous() {

        let file = File(contents: """
            protocol DataConfiguring { }

            protocol DataProviding { }

            final class Coordinator {
                // weaver: value <= Int
            }

            final class AppDelegate {

                // weaver: coordinator = Coordinator
                // weaver: coordinator.scope = .transient

                // weaver: dataConfiguration = DataManager <- DataConfiguring
                // weaver: dataConfiguration.scope = .container
                // weaver: dataConfiguration.builder = { _ in DataManager.shared }

                // weaver: dataProvider = DataManager <- DataProviding
                // weaver: dataProvider.scope = .container
                // weaver: dataProvider.builder = { _ in DataManager.shared }

                // weaver: viewController1 = ViewController1
                // weaver: viewController1.scope = .transient

                // weaver: dataConfiguration.platforms = [.watchOS]
                // weaver: dataProvider.platforms = [.watchOS]
            }

            final class DataManager: DataConfiguring, DataProviding {
                // weaver: viewController2 = ViewController2
                // weaver: viewController2.scope = .transient
            }

            final class ViewController1: UIViewController {
                // weaver: coordinator <= Coordinator
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
            let linker = try Linker(syntaxTrees: [syntaxTree], platform: .iOS)

            guard linker.dependencyGraph.dependencies.count == 5 else {
                XCTFail("Incorrect number of dependencies found \(linker.dependencyGraph.dependencies.count), but expected 5.")
                return
            }
            XCTAssertEqual(linker.dependencyGraph.dependencies[0].dependencyName, "value")
            XCTAssertEqual(linker.dependencyGraph.dependencies[1].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[2].dependencyName, "viewController1")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "coordinator")
            XCTAssertEqual(linker.dependencyGraph.dependencies[3].dependencyName, "coordinator")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

}
