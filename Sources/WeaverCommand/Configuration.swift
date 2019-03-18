//
//  Configuration.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 2/4/19.
//

import Foundation
import PathKit
import Yams

// MARK: - Configuration

struct Configuration {
    let projectPath: Path
    let outputPath: Path
    let mainTemplatePath: Path
    let detailedResolversTemplatePath: Path
    let inputPathStrings: [String]
    let ignoredPathStrings: [String]
    let unsafe: Bool
    let singleOutput: Bool
    let recursiveOff: Bool
    let detailedResolvers: Bool
    
    private init(inputPathStrings: [String]?,
                 ignoredPathStrings: [String]?,
                 projectPath: Path?,
                 outputPath: Path?,
                 mainTemplatePath: Path?,
                 detailedResolversTemplatePath: Path?,
                 unsafe: Bool?,
                 singleOutput: Bool?,
                 recursiveOff: Bool?,
                 detailedResolvers: Bool?) {

        self.inputPathStrings = inputPathStrings ?? Defaults.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? []
        self.projectPath = projectPath ?? Defaults.projectPath
        self.outputPath = outputPath ?? Defaults.outputPath
        self.mainTemplatePath = mainTemplatePath ?? Defaults.mainTemplatePath
        self.detailedResolversTemplatePath = detailedResolversTemplatePath ?? Defaults.detailedResolversTemplatePath
        self.unsafe = unsafe ?? Defaults.unsafe
        self.singleOutput = singleOutput ?? Defaults.singleOuput
        self.recursiveOff = recursiveOff ?? Defaults.recursiveOff
        self.detailedResolvers = detailedResolvers ?? Defaults.detailedResolvers
    }
    
    init(configPath: Path? = nil,
         inputPathStrings: [String]? = nil,
         ignoredPathStrings: [String]? = nil,
         projectPath: Path? = nil,
         outputPath: Path? = nil,
         mainTemplatePath: Path? = nil,
         detailedResolversTemplatePath: Path? = nil,
         unsafe: Bool? = nil,
         singleOutput: Bool? = nil,
         recursiveOff: Bool? = nil,
         detailedResolvers: Bool? = nil) throws {
        
        let projectPath = projectPath ?? Defaults.projectPath
        let configPath = Configuration.prepareConfigPath(configPath ?? Defaults.configPath,
                                                         projectPath: projectPath)
        
        var configuration: Configuration
        switch (configPath.extension, configPath.isFile) {
        case ("json"?, true):
            let jsonDecoder = JSONDecoder()
            configuration = try jsonDecoder.decode(Configuration.self, from: try configPath.read())
        case ("yaml"?, true):
            let yamlDecoder = YAMLDecoder()
            configuration = try yamlDecoder.decode(Configuration.self, from: try configPath.read(), userInfo: [:])
        default:
            configuration = Configuration(inputPathStrings: inputPathStrings,
                                          ignoredPathStrings: ignoredPathStrings,
                                          projectPath: projectPath,
                                          outputPath: outputPath,
                                          mainTemplatePath: mainTemplatePath,
                                          detailedResolversTemplatePath: detailedResolversTemplatePath,
                                          unsafe: unsafe,
                                          singleOutput: singleOutput,
                                          recursiveOff: recursiveOff,
                                          detailedResolvers: detailedResolvers)
        }
        
        self.inputPathStrings = inputPathStrings ?? configuration.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? configuration.ignoredPathStrings
        self.projectPath = projectPath
        self.unsafe = unsafe ?? configuration.unsafe
        self.singleOutput = singleOutput ?? configuration.singleOutput
        self.recursiveOff = recursiveOff ?? configuration.recursiveOff
        self.detailedResolvers = detailedResolvers ?? configuration.detailedResolvers
        
        let outputPath = outputPath ?? configuration.outputPath
        self.outputPath = outputPath.isRelative ? projectPath + configuration.outputPath : outputPath

        let mainTemplatePath = mainTemplatePath ?? configuration.mainTemplatePath
        var shouldUseProjectPath = mainTemplatePath.isRelative && mainTemplatePath != Defaults.mainTemplatePath
        self.mainTemplatePath = shouldUseProjectPath ? projectPath + mainTemplatePath : mainTemplatePath
        
        let detailedResolversTemplatePath = detailedResolversTemplatePath ?? configuration.detailedResolversTemplatePath
        shouldUseProjectPath = detailedResolversTemplatePath.isRelative && detailedResolversTemplatePath != Defaults.detailedResolversTemplatePath
        self.detailedResolversTemplatePath = shouldUseProjectPath ? projectPath + detailedResolversTemplatePath : detailedResolversTemplatePath
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
    
    private var recursive: Bool {
        return !recursiveOff
    }
}

// MARK: - Constants

extension Configuration {

    enum Defaults {
        static let configPath = Path(".")
        static let configYAMLFile = Path(".weaver.yaml")
        static let configJSONFile = Path(".weaver.json")
        static let outputPath = Path(".")
        static let unsafe = false
        static let singleOuput = false
        static let recursiveOff = false
        static let inputPathStrings = ["."]
        static let detailedResolvers = false
        
        static var projectPath: Path {
            if let projectPath = ProcessInfo.processInfo.environment["WEAVER_PROJECT_PATH"] {
                return Path(projectPath)
            } else {
                return Path(".")
            }
        }

        static var mainTemplatePath: Path {
            if let mainTemplatePath = ProcessInfo.processInfo.environment["WEAVER_MAIN_TEMPLATE_PATH"] {
                return Path(mainTemplatePath)
            } else {
                return Path("/usr/local/share/weaver/Resources/dependency_resolver.stencil")
            }
        }
        
        static var detailedResolversTemplatePath: Path {
            if let detailedResolversTemplatePath = ProcessInfo.processInfo.environment["WEAVER_DETAILED_RESOLVERS_TEMPLATE_PATH"] {
                return Path(detailedResolversTemplatePath)
            } else {
                return Path("/usr/local/share/weaver/Resources/detailed_resolvers.stencil")
            }
        }
    }
}

// MARK: - Decodable

extension Configuration: Decodable {

    private enum Keys: String, CodingKey {
        case projectPath = "project_path"
        case outputPath = "output_path"
        case mainTemplatePath = "main_template_path"
        case detailedResolversTemplatePath = "detailed_resolvers_template_path"
        case inputPaths = "input_paths"
        case ignoredPaths = "ignored_paths"
        case unsafe
        case singleOutput = "single_output"
        case recursive
        case detailedResolvers = "detailed_resolvers"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        if container.contains(.projectPath) {
            Logger.log(.error, "\(Keys.projectPath.rawValue) cannot be overriden in the configuration file.")
        }
        
        projectPath = Defaults.projectPath
        outputPath = try container.decodeIfPresent(Path.self, forKey: .outputPath) ?? Defaults.outputPath
        mainTemplatePath = try container.decodeIfPresent(Path.self, forKey: .mainTemplatePath) ?? Defaults.mainTemplatePath
        detailedResolversTemplatePath = try container.decodeIfPresent(Path.self, forKey: .detailedResolversTemplatePath) ?? Defaults.detailedResolversTemplatePath
        inputPathStrings = try container.decodeIfPresent([String].self, forKey: .inputPaths) ?? Defaults.inputPathStrings
        ignoredPathStrings = try container.decodeIfPresent([String].self, forKey: .ignoredPaths) ?? []
        unsafe = try container.decodeIfPresent(Bool.self, forKey: .unsafe) ?? Defaults.unsafe
        singleOutput = try container.decodeIfPresent(Bool.self, forKey: .singleOutput) ?? Defaults.singleOuput
        recursiveOff = !(try container.decodeIfPresent(Bool.self, forKey: .recursive) ?? !Defaults.recursiveOff)
        detailedResolvers = try container.decodeIfPresent(Bool.self, forKey: .detailedResolvers) ?? Defaults.detailedResolvers
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
    
    func inputPaths() throws -> [Path]  {

        let inputPaths = try Set(inputPathStrings
            .map { projectPath + $0 }
            .flatMap { $0.isFile ? [$0] : recursive ? try $0.recursiveChildren() : try $0.children() }
            .filter { $0.extension == "swift" })
        
        let ignoredPaths = try Set(ignoredPathStrings
            .map { projectPath + $0 }
            .flatMap { $0.isFile ? [$0] : recursive ? try $0.recursiveChildren() : try $0.children() }
            .filter { $0.extension == "swift" })
        
        return inputPaths.subtracting(ignoredPaths).sorted()
    }
}
