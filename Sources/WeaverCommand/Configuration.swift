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
    let recursiveOff: Bool
    
    private init(inputPathStrings: [String]?,
                 ignoredPathStrings: [String]?,
                 projectPath: Path?,
                 outputPath: Path?,
                 templatePath: Path?,
                 unsafe: Bool?,
                 singleOutput: Bool?,
                 recursiveOff: Bool?) {

        self.inputPathStrings = inputPathStrings ?? Defaults.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? []
        self.projectPath = projectPath ?? Defaults.projectPath
        self.outputPath = outputPath ?? Defaults.outputPath
        self.templatePath = templatePath ?? Defaults.templatePath
        self.unsafe = unsafe ?? Defaults.unsafe
        self.singleOutput = singleOutput ?? Defaults.singleOuput
        self.recursiveOff = recursiveOff ?? Defaults.recursiveOff
    }
    
    init(configPath: Path? = nil,
         inputPathStrings: [String]? = nil,
         ignoredPathStrings: [String]? = nil,
         projectPath: Path? = nil,
         outputPath: Path? = nil,
         templatePath: Path? = nil,
         unsafe: Bool? = nil,
         singleOutput: Bool? = nil,
         recursiveOff: Bool? = nil) throws {
        
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
                                          singleOutput: singleOutput,
                                          recursiveOff: recursiveOff)
        }
        
        self.inputPathStrings = inputPathStrings ?? configuration.inputPathStrings
        self.ignoredPathStrings = ignoredPathStrings ?? configuration.ignoredPathStrings
        self.projectPath = projectPath
        self.unsafe = unsafe ?? configuration.unsafe
        self.singleOutput = singleOutput ?? configuration.singleOutput
        self.recursiveOff = recursiveOff ?? configuration.recursiveOff
        
        let outputPath = outputPath ?? configuration.outputPath
        self.outputPath = outputPath.isRelative ? projectPath + configuration.outputPath : outputPath

        let templatePath = templatePath ?? configuration.templatePath
        let shouldUseProjectPath = templatePath.isRelative && templatePath != Defaults.templatePath
        self.templatePath = shouldUseProjectPath ? projectPath + templatePath : templatePath
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
        
        static var projectPath: Path {
            if let projectPath = ProcessInfo.processInfo.environment["WEAVER_PROJECT_PATH"] {
                return Path(projectPath)
            } else {
                return Path(".")
            }
        }

        static var templatePath: Path {
            if let templatePath = ProcessInfo.processInfo.environment["WEAVER_TEMPLATE_PATH"] {
                return Path(templatePath)
            } else {
                return Path("/usr/local/share/weaver/Resources/dependency_resolver.stencil")
            }
        }
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
        case recursive
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        if container.contains(.projectPath) {
            Logger.log(.error, "\(Keys.projectPath.rawValue) cannot be overriden in the configuration file.")
        }
        
        projectPath = Defaults.projectPath
        outputPath = try container.decodeIfPresent(Path.self, forKey: .outputPath) ?? Defaults.outputPath
        templatePath = try container.decodeIfPresent(Path.self, forKey: .templatePath) ?? Defaults.templatePath
        inputPathStrings = try container.decodeIfPresent([String].self, forKey: .inputPaths) ?? Defaults.inputPathStrings
        ignoredPathStrings = try container.decodeIfPresent([String].self, forKey: .ignoredPaths) ?? []
        unsafe = try container.decodeIfPresent(Bool.self, forKey: .unsafe) ?? Defaults.unsafe
        singleOutput = try container.decodeIfPresent(Bool.self, forKey: .singleOutput) ?? Defaults.singleOuput
        recursiveOff = !(try container.decodeIfPresent(Bool.self, forKey: .recursive) ?? !Defaults.recursiveOff)
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
