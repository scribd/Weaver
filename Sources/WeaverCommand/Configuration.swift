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
    let templatePath: Path
    let inputPathStrings: [String]
    let ignoredPathStrings: [String]
    let unsafe: Bool
    let singleOutput: Bool
    
    private init(inputPathStrings: [String]?,
                 ignoredPathStrings: [String]?,
                 projectPath: Path?,
                 outputPath: Path?,
                 templatePath: Path?,
                 unsafe: Bool?,
                 singleOutput: Bool?) {

        self.inputPathStrings = inputPathStrings ?? []
        self.ignoredPathStrings = ignoredPathStrings ?? []
        self.projectPath = projectPath ?? Defaults.projectPath
        self.outputPath = outputPath ?? Defaults.outputPath
        self.templatePath = templatePath ?? Defaults.templatePath
        self.unsafe = unsafe ?? Defaults.unsafe
        self.singleOutput = singleOutput ?? Defaults.singleOuput
    }
    
    init(configPath: Path? = nil,
         inputPathStrings: [String]? = nil,
         ignoredPathStrings: [String]? = nil,
         projectPath: Path? = nil,
         outputPath: Path? = nil,
         templatePath: Path? = nil,
         unsafe: Bool? = nil,
         singleOutput: Bool? = nil) throws {
        
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
                                          templatePath: templatePath,
                                          unsafe: unsafe,
                                          singleOutput: singleOutput)
        }
        
        self.inputPathStrings = inputPathStrings ?? configuration.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? configuration.ignoredPathStrings
        self.projectPath = projectPath
        self.unsafe = unsafe ?? configuration.unsafe
        self.singleOutput = singleOutput ?? configuration.singleOutput
        
        let outputPath = outputPath ?? configuration.outputPath
        self.outputPath = outputPath.isRelative ? projectPath + configuration.outputPath : outputPath

        let templatePath = templatePath ?? configuration.templatePath
        self.templatePath = templatePath.isRelative ? projectPath + templatePath : templatePath
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
}

// MARK: - Constants

extension Configuration {

    enum Defaults {
        static let configPath = Path(".")
        static let configYAMLFile = Path(".weaver.yaml")
        static let configJSONFile = Path(".weaver.json")
        static let projectPath = Path(".")
        static let outputPath = Path(".")
        static let templatePath = Path("/usr/local/share/weaver/Resources/dependency_resolver.stencil")
        static let unsafe = false
        static let singleOuput = false
    }
}

// MARK: - Decodable

extension Configuration: Decodable {

    private enum Keys: String, CodingKey {
        case projectPath = "project_path"
        case outputPath = "output_path"
        case templatePath = "template_path"
        case inputPaths = "input_paths"
        case ignoredPaths = "ignored_paths"
        case unsafe
        case singleOutput = "single_output"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        if container.contains(.projectPath) {
            Logger.log(.error, "\(Keys.projectPath.rawValue) cannot be overriden in the configuration file.")
        }
        
        projectPath = Defaults.projectPath
        outputPath = try container.decodeIfPresent(Path.self, forKey: .outputPath) ?? Defaults.outputPath
        templatePath = try container.decodeIfPresent(Path.self, forKey: .templatePath) ?? Defaults.templatePath
        inputPathStrings = try container.decode([String].self, forKey: .inputPaths)
        ignoredPathStrings = try container.decodeIfPresent([String].self, forKey: .ignoredPaths) ?? []
        unsafe = try container.decodeIfPresent(Bool.self, forKey: .unsafe) ?? Defaults.unsafe
        singleOutput = try container.decodeIfPresent(Bool.self, forKey: .singleOutput) ?? Defaults.singleOuput
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
    
    var inputPaths: [Path] {
        let inputPaths = Set(inputPathStrings.flatMap { projectPath.glob($0) })
        let ignoredPaths = Set(ignoredPathStrings.flatMap { projectPath.glob($0) })
        return inputPaths.subtracting(ignoredPaths).sorted()
    }
}
