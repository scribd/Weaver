//
//  Configuration.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 2/4/19.
//

import Foundation
import PathKit
import Yams
import ShellOut
import WeaverCodeGen

// MARK: - Configuration

struct Configuration {

    let projectName: String?
    let projectPath: Path
    let mainOutputPath: Path
    let testsOutputPath: Path
    let inputPathStrings: [String]
    let ignoredPathStrings: [String]
    let cachePath: Path
    let recursiveOff: Bool
    let tests: Bool
    let allowTestsToInitRealDependencies: Bool
    let testableImports: [String]?
    let swiftlintDisableAll: Bool
    let platform: Platform?
    let includedImports: Set<String>?
    let excludedImports: Set<String>?
    
    private init(inputPathStrings: [String]?,
                 ignoredPathStrings: [String]?,
                 projectName: String?,
                 projectPath: Path?,
                 mainOutputPath: Path?,
                 testsOutputPath: Path?,
                 cachePath: Path?,
                 recursiveOff: Bool?,
                 tests: Bool?,
                 allowTestsToInitRealDependencies: Bool?,
                 testableImports: [String]?,
                 swiftlintDisableAll: Bool?,
                 platform: Platform?,
                 includedImports: Set<String>?,
                 excludedImports: Set<String>?) {

        self.inputPathStrings = inputPathStrings ?? Defaults.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? []

        self.projectName = projectName
        self.projectPath = projectPath ?? Defaults.projectPath

        self.mainOutputPath = mainOutputPath ?? Defaults.mainOutputPath
        self.testsOutputPath = testsOutputPath ?? Defaults.testsOutputPath

        self.cachePath = cachePath ?? Defaults.cachePath
        self.recursiveOff = recursiveOff ?? Defaults.recursiveOff
        self.tests = tests ?? Defaults.tests
        self.allowTestsToInitRealDependencies = allowTestsToInitRealDependencies ?? Defaults.allowTestsToInitRealDependencies
        self.testableImports = testableImports
        self.swiftlintDisableAll = swiftlintDisableAll ?? Defaults.swiftlintDisableAll
        self.platform = platform
        self.includedImports = includedImports
        self.excludedImports = excludedImports
    }
    
    init(configPath: Path? = nil,
         inputPathStrings: [String]? = nil,
         ignoredPathStrings: [String]? = nil,
         projectName: String? = nil,
         projectPath: Path? = nil,
         mainOutputPath: Path? = nil,
         testsOutputPath: Path? = nil,
         cachePath: Path? = nil,
         recursiveOff: Bool? = nil,
         tests: Bool? = nil,
         allowTestsToInitRealDependencies: Bool? = nil,
         testableImports: [String]? = nil,
         swiftlintDisableAll: Bool? = nil,
         platform: Platform? = nil,
         includedImports: Set<String>? = nil,
         excludedImports: Set<String>? = nil) throws {
        
        let projectPath = projectPath ?? Defaults.projectPath
        let configPath = Configuration.prepareConfigPath(configPath ?? Defaults.configPath, projectPath: projectPath)
        let _cachePath = Configuration.prepareCachePath(cachePath ?? Defaults.cachePath, projectPath: projectPath)
        
        var configuration: Configuration
        switch (configPath.extension, configPath.isFile) {
        case ("json"?, true):
            let jsonDecoder = JSONDecoder()
            configuration = try jsonDecoder.decode(Configuration.self, from: try configPath.read())
        case ("yaml"?, true):
            let yamlDecoder = YAMLDecoder()
            configuration = try yamlDecoder.decode(Configuration.self, from: try configPath.read())
        default:
            configuration = Configuration(
                inputPathStrings: inputPathStrings,
                ignoredPathStrings: ignoredPathStrings,
                projectName: projectName,
                projectPath: projectPath,
                mainOutputPath: mainOutputPath,
                testsOutputPath: testsOutputPath,
                cachePath: _cachePath,
                recursiveOff: recursiveOff,
                tests: tests,
                allowTestsToInitRealDependencies: allowTestsToInitRealDependencies,
                testableImports: testableImports,
                swiftlintDisableAll: swiftlintDisableAll,
                platform: platform,
                includedImports: includedImports,
                excludedImports: excludedImports
            )
        }
        
        self.inputPathStrings = inputPathStrings ?? configuration.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? configuration.ignoredPathStrings
        self.projectName = projectName ?? configuration.projectName
        self.projectPath = projectPath

        let outputPath: Path? = mainOutputPath ?? configuration.mainOutputPath
        self.mainOutputPath = outputPath
            .map { $0.extension == "swift" ? $0 : $0 + Defaults.mainOutputFileName }
            .map { $0.isRelative ? projectPath + $0 : $0 } ?? Defaults.mainOutputPath
        let testPath: Path? = testsOutputPath ?? configuration.testsOutputPath
        self.testsOutputPath = testPath
            .map { $0.extension == "swift" ? $0 : $0 + Defaults.testOutputFileName }
            .map { $0.isRelative ? projectPath + $0 : $0 } ?? Defaults.testsOutputPath
        self.cachePath = cachePath ?? configuration.cachePath
        self.recursiveOff = recursiveOff ?? configuration.recursiveOff
        self.tests = tests ?? configuration.tests
        self.allowTestsToInitRealDependencies = allowTestsToInitRealDependencies ?? configuration.allowTestsToInitRealDependencies
        self.testableImports = testableImports ?? configuration.testableImports
        self.swiftlintDisableAll = swiftlintDisableAll ?? configuration.swiftlintDisableAll
        self.platform = platform ?? configuration.platform
        self.includedImports = includedImports ?? configuration.includedImports
        self.excludedImports = excludedImports ?? configuration.excludedImports
    }
    
    private static func prepareConfigPath(_ configPath: Path, projectPath: Path) -> Path {
        let configPath = configPath.isRelative ? projectPath + configPath : configPath
        if configPath.isDirectory {
            if (configPath + Defaults.configJSONFile).isFile {
                return configPath + Defaults.configJSONFile
            } else if (configPath + Defaults.configYAMLFile).isFile {
                return configPath + Defaults.configYAMLFile
            }
        }
        return configPath
    }
    
    private static func prepareCachePath(_ cachePath: Path, projectPath: Path) -> Path {
        return cachePath.isRelative ? projectPath + cachePath : cachePath
    }
    
    private var recursive: Bool {
        return recursiveOff == false
    }
}

// MARK: - Constants

extension Configuration {

    enum Defaults {
        static let configPath = Path(".")
        static let configYAMLFile = Path(".weaver.yaml")
        static let configJSONFile = Path(".weaver.json")
        static let mainOutputFileName = Path("Weaver.swift")
        static let mainOutputPath = Path(".") + mainOutputFileName
        static let testOutputFileName = Path("WeaverTests.swift")
        static let testsOutputPath = Path(".") + testOutputFileName
        static let cachePath = Path(".weaver_cache.json")
        static let recursiveOff = false
        static let inputPathStrings = ["."]
        static let detailedResolvers = false
        static let tests = false
        static let allowTestsToInitRealDependencies = false
        static let swiftlintDisableAll = true
        
        static var projectPath: Path {
            if let projectPath = ProcessInfo.processInfo.environment["WEAVER_PROJECT_PATH"] {
                return Path(projectPath)
            } else {
                return Path(".")
            }
        }
    }
}

// MARK: - Decodable

extension Configuration: Decodable {

    private enum Keys: String, CodingKey {
        case projectName = "project_name"
        case projectPath = "project_path"
        case mainOutputPath = "main_output_path"
        case testsOutputPath = "tests_output_path"
        case inputPaths = "input_paths"
        case ignoredPaths = "ignored_paths"
        case recursive
        case tests
        case allowTestsToInitRealDependencies = "allow_tests_to_init_real_dependencies"
        case testableImports = "testable_imports"
        case cachePath = "cache_path"
        case swiftlintDisableAll = "swiftlint_disable_all"
        case platform
        case includedImports = "included_imports"
        case excludedImports = "excluded_imports"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        if container.contains(.projectPath) {
            Logger.log(.error, "\(Keys.projectPath.rawValue) cannot be overriden in the configuration file.")
        }

        let recursive = try container.decodeIfPresent(Bool.self, forKey: .recursive)

        self.init(
            inputPathStrings: try container.decodeIfPresent([String].self, forKey: .inputPaths),
            ignoredPathStrings: try container.decodeIfPresent([String].self, forKey: .ignoredPaths),
            projectName: try container.decodeIfPresent(String.self, forKey: .projectName),
            projectPath: nil,
            mainOutputPath: try container.decodeIfPresent(Path.self, forKey: .mainOutputPath),
            testsOutputPath: try container.decodeIfPresent(Path.self, forKey: .testsOutputPath),
            cachePath: try container.decodeIfPresent(Path.self, forKey: .cachePath),
            recursiveOff: recursive.map { !$0 },
            tests: try container.decodeIfPresent(Bool.self, forKey: .tests),
            allowTestsToInitRealDependencies: try container.decodeIfPresent(Bool.self, forKey: .allowTestsToInitRealDependencies),
            testableImports: try container.decodeIfPresent([String].self, forKey: .testableImports),
            swiftlintDisableAll: try container.decodeIfPresent(Bool.self, forKey: .swiftlintDisableAll),
            platform: try container.decodeIfPresent(Platform.self, forKey: .platform),
            includedImports: try container.decodeIfPresent(Set<String>.self, forKey: .includedImports),
            excludedImports: try container.decodeIfPresent(Set<String>.self, forKey: .excludedImports)
        )
    }
}

extension Path: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }
}

// MARK: - Utils

extension Configuration {
    
    private static let annotationRegex = "\\/\\/[[:space:]]*\(TokenBuilder.annotationRegexString)"
    private static let propertyWrapperRegex = "\"@\\w*Weaver\""
    
    func inputPaths() throws -> [Path]  {
        var inputPaths = Set<Path>()
        var fullIgnoredPaths = Set<Path>()

        inputPaths.formUnion(inputPathStrings
            .lazy
            .map { self.projectPath + $0 }
            .flatMap { $0.isFile ? [$0] : self.recursivePathsByPattern(fromDirectory: $0) }
            .filter { $0.exists && $0.isFile && $0.extension == "swift" }
            .map { $0.absolute() })

        fullIgnoredPaths.formUnion(ignoredPathStrings
            .lazy
            .map { self.projectPath + $0 }
            .flatMap { $0.isFile ? [$0] : self.recursivePathsByPattern(fromDirectory: $0) }
            .filter { $0.exists && $0.isFile && $0.extension == "swift" }
            .map { $0.absolute() })

        inputPaths.subtract(try fullIgnoredPaths
            .lazy
            .map { self.projectPath + $0 }
            .flatMap { $0.isFile ? [$0] : try paths(fromDirectory: $0) }
            .filter { $0.extension == "swift" }
            .map { $0.absolute() })
        
        return inputPaths.sorted()
    }

    private func recursivePathsByPattern(fromDirectory directory: Path) -> [Path] {
        let grepArguments = [
            "-lR",
            "-e", Configuration.annotationRegex,
            "-e", Configuration.propertyWrapperRegex,
            "\"\(directory.absolute().string)\""
        ]
        
        // When there is no file matching the pattern,
        // `grep` fails, and ShellOut throws an exception with an empty message.
        guard let grepResult = try? shellOut(to: "grep", arguments: grepArguments) else {
            return []
        }

        return grepResult
            .split(separator: "\n")
            .map { Path(String($0)) }
    }

    private func paths(fromDirectory directory: Path) throws -> [Path] {
        recursive ? try directory.recursiveChildren() : try directory.children()
    }
        
    func importFilter(_ module: String) -> Bool {
        switch (includedImports, excludedImports) {
        case (.some(let includedImports), nil):
            return includedImports.contains(module)
        case (nil, .some(let excludedImports)):
            return excludedImports.contains(module) == false
        case (.some(let includedImports), .some(let excludedImports)):
            return includedImports.contains(module) && excludedImports.contains(module) == false
        case (nil, nil):
            return true
        }
    }
}
