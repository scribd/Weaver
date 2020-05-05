//
//  CommandTests.swift
//  WeaverCommandTests
//
//  Created by Théophane Rupin on 6/22/18.
//

import WeaverCommand
import PathKit
import ShellOut
import XCTest

final class CommandTests: XCTestCase {
    
    private enum Constants {
        static let samplePath = Path(#file) + "../../../Sample"
        static let mainOutputPath = samplePath + "Sample/Generated/Weaver.swift"
        static let apiOutputPath = samplePath + "API/Generated/Weaver.swift"
        static let cachePath = samplePath + ".weaver_cache.json"
        static let diffsPath = Path("/tmp/weaver_tests/\(CommandTests.self)")
        
        static let initialMainOutput: String = try! mainOutputPath.read()
        static let initialAPIOutput: String = try! apiOutputPath.read()
    }

    private func run(command: String, with config: String) throws {
        try weaverCommand.run([command, "--project-path", Constants.samplePath.absolute().string, "--config-path", config])
    }
    
    func exportDiff(actual: String, expected: String, _ function: StringLiteralType = #function) throws {
        guard actual != expected else { return }

        let function = function.replacingOccurrences(of: "()", with: "")
        let actualFilePath = Constants.diffsPath + "\(function)_actual.swift"
        let expectedFilePath = Constants.diffsPath + "\(function)_expected.swift"

        try Constants.diffsPath.mkpath()
        try actualFilePath.write(actual)
        try expectedFilePath.write(expected)

        print("Execute the following to check the diffs:")
        print("\n")
        print("diffchecker \(actualFilePath.string) \(expectedFilePath.string)")
        print("\n")
    }
    
    func test_weaver_swift_should_create_cache_file() throws {
        try run(command: "swift", with: ".sample.weaver.yaml")
        XCTAssertGreaterThan(try Constants.cachePath.read().count, 35)
    }
    
    func test_weaver_clean_should_remove_cache_file() throws {
        try run(command: "swift", with: ".sample.weaver.yaml")
        try run(command: "clean", with: ".sample.weaver.yaml")
        XCTAssertEqual(try Constants.cachePath.read().count, 35)
    }
    
    func test_weaver_swift_should_generate_code_for_sample() throws {
        try run(command: "clean", with: ".sample.weaver.yaml")
        try run(command: "swift", with: ".sample.weaver.yaml")
        let actualOutput: String = try Constants.mainOutputPath.read()
        XCTAssertEqual(actualOutput, Constants.initialMainOutput)
        try exportDiff(actual: actualOutput, expected: Constants.initialMainOutput)
    }
    
    func test_weaver_swift_should_generate_code_for_api() throws {
        try run(command: "clean", with: ".api.weaver.yaml")
        try run(command: "swift", with: ".api.weaver.yaml")
        let actualOutput: String = try Constants.apiOutputPath.read()
        XCTAssertEqual(actualOutput, Constants.initialAPIOutput)
        try exportDiff(actual: actualOutput, expected: Constants.initialAPIOutput)
    }
}
