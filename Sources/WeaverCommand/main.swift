//
//  main.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation
import Commander
import WeaverCodeGen
import SourceKittenFramework
import Darwin
import PathKit
import Rainbow

private let version = "0.11.2"

// MARK: - Linker

private extension Linker {

    convenience init(_ inputPaths: [Path], shouldLog: Bool = true) throws {

        // ---- Parse ----

        if shouldLog {
            Logger.log(.info, "")
            Logger.log(.info, "Parsing...".yellow, benchmark: .start("parsing"))
        }
        let asts: [Expr] = try inputPaths.compactMap { filePath in
            guard let file = File(path: filePath.string) else {
                return nil
            }
            
            if shouldLog { Logger.log(.info, "<- '\(filePath)'".yellow) }
            let tokens = try Lexer(file, fileName: filePath.string).tokenize()
            return try Parser(tokens, fileName: filePath.string).parse()
        }
        if shouldLog { Logger.log(.info, "Done".yellow, benchmark: .end("parsing")) }

        // ---- Link ----
        
        
        if shouldLog {
            Logger.log(.info, "")
            Logger.log(.info, "Linking...".lightGreen, benchmark: .start("linking"))
        }
        try self.init(syntaxTrees: asts)
        if shouldLog { Logger.log(.info, "Done".lightGreen, benchmark: .end("linking")) }
    }
}

// MARK: - Parameters

private enum Parameters {
    static let projectPath = Option<Path?>("project_path", default: nil, description: "Project's directory.")
    static let configPath = Option<Path?>("config_path", default: nil, description: "Configuration path.")
    static let outputPath = Option<Path?>("output_path", default: nil, description: "Where the swift files will be generated.")
    static let templatePath = Option<Path?>("template_path", default: nil, description: "Custom template path.")
    static let unsafe = OptionalFlag("unsafe", disabledName: "safe")
    static let singleOutput = OptionalFlag("single_output", disabledName: "multi_outputs")
    static let inputPath = VariadicOption<String>("input_path", default: [], description: "Paths to input files.")
    static let ignoredPath = VariadicOption<String>("ignored_path", default: [], description: "Paths to ignore.")
    static let pretty = Flag("pretty", default: false)
}

// MARK: - Commands

let main = Group {
    
    $0.command(
        "generate",
        Parameters.projectPath,
        Parameters.configPath,
        Parameters.outputPath,
        Parameters.templatePath,
        Parameters.unsafe,
        Parameters.singleOutput,
        Parameters.inputPath,
        Parameters.ignoredPath)
    { projectPath, configPath, outputPath, templatePath, unsafe, singleOutput, inputPaths, ignoredPaths in

        let configuration = try Configuration(configPath: configPath,
                                              inputPathStrings: inputPaths.isEmpty ? nil : inputPaths,
                                              ignoredPathStrings: ignoredPaths.isEmpty ? nil : ignoredPaths,
                                              projectPath: projectPath,
                                              outputPath: outputPath,
                                              templatePath: templatePath,
                                              unsafe: unsafe,
                                              singleOutput: singleOutput)
        
        Logger.log(.info, "Let the injection begin.".lightRed, benchmark: .start("all"))

        // ---- Link ----

        let linker = try Linker(configuration.inputPaths)
        let dependencyGraph = linker.dependencyGraph

        // ---- Generate ----

        Logger.log(.info, "")
        Logger.log(.info, "Generating boilerplate code...".lightBlue, benchmark: .start("generating"))

        let generator = try SwiftGenerator(dependencyGraph: dependencyGraph,
                                           version: version,
                                           template: configuration.templatePath)

        let generatedData: [(file: String, data: String?)] = try {
            if configuration.singleOutput {
                return [(file: "swift", data: try generator.generate())]
            } else {
                return try generator.generate()
            }
        }()

        Logger.log(.info, "Done".lightBlue, benchmark: .end("generating"))

        // ---- Collect ----

        let dataToWrite: [(path: Path, data: String?)] = generatedData.compactMap { (file, data) in

            let filePath = Path(file)

            guard let fileName = filePath.components.last else {
                Logger.log(.error, "Could not retrieve file name from path '\(filePath)'".red)
                return nil
            }
            let generatedFilePath = configuration.outputPath + "Weaver.\(fileName)"

            guard let data = data else {
                Logger.log(.info, "-- No Weaver annotation found in file '\(filePath)'.".red)
                return (path: generatedFilePath, data: nil)
            }

            return (path: generatedFilePath, data: data)
        }

        // ---- Inspect ----

        if !configuration.unsafe {
            Logger.log(.info, "")
            Logger.log(.info, "Checking dependency graph...".magenta, benchmark: .start("checking"))

            let inspector = Inspector(dependencyGraph: dependencyGraph)
            try inspector.validate()

            Logger.log(.info, "Done".magenta, benchmark: .end("checking"))
        }

        // ---- Write ----

        Logger.log(.info, "")
        Logger.log(.info, "Writing...".lightMagenta, benchmark: .start("writing"))

        for (path, data) in dataToWrite {
            if let data = data {
                try path.parent().mkpath()
                try path.write(data)
                Logger.log(.info, "-> '\(path)'".lightMagenta)
            } else if path.isFile && path.isDeletable {
                try path.parent().mkpath()
                try path.delete()
                Logger.log(.info, " X '\(path)'".lightMagenta)
            }
        }

        Logger.log(.info, "Done".lightMagenta, benchmark: .end("writing"))
        Logger.log(.info, "")
        Logger.log(.info, "Injection done in \(dependencyGraph.injectableTypesCount) different types".lightWhite, benchmark: .end("all"))

    }
    
    $0.command(
        "export",
        Parameters.projectPath,
        Parameters.configPath,
        Parameters.pretty,
        Parameters.inputPath,
        Parameters.ignoredPath
    ) { projectPath, configPath, pretty, inputPaths, ignoredPaths in
        
        let configuration = try Configuration(configPath: configPath,
                                              inputPathStrings: inputPaths.isEmpty ? nil : inputPaths,
                                              ignoredPathStrings: ignoredPaths.isEmpty ? nil : ignoredPaths,
                                              projectPath: projectPath)
        
        // ---- Link ----

        let linker = try Linker(configuration.inputPaths, shouldLog: false)
        let dependencyGraph = linker.dependencyGraph

        // ---- Export ----

        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = .prettyPrinted
        }
        let jsonData = try encoder.encode(dependencyGraph)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.log(.error, "Could not generate json from data.")
            exit(1)
        }
        
        Logger.log(.info, jsonString)
    }
    
    $0.command(
        "xcfilelist",
        Parameters.configPath,
        Parameters.outputPath,
        Parameters.projectPath,
        Parameters.singleOutput,
        Parameters.inputPath,
        Parameters.ignoredPath
    ) { configPath, outputPath, projectPath, singleOutput, inputPaths, ignoredPaths in

        let configuration = try Configuration(configPath: configPath,
                                              inputPathStrings: inputPaths.isEmpty ? nil : inputPaths,
                                              ignoredPathStrings: ignoredPaths.isEmpty ? nil : ignoredPaths,
                                              projectPath: projectPath,
                                              singleOutput: singleOutput)

        // ---- Link ----

        let linker = try Linker(configuration.inputPaths)
        let dependencyGraph = linker.dependencyGraph

        // ---- Write ----

        Logger.log(.info, "")
        Logger.log(.info, "Writing...".lightMagenta, benchmark: .start("writing"))

        let generator = XCFilelistGenerator(dependencyGraph: dependencyGraph,
                                            projectPath: configuration.projectPath,
                                            outputPath: configuration.outputPath,
                                            singleOutput: configuration.singleOutput,
                                            version: version)

        let filelists = generator.generate()

        let inputFilelistPath = configuration.outputPath + "WeaverInput.xcfilelist"
        try inputFilelistPath.parent().mkpath()
        try inputFilelistPath.write(filelists.input)
        Logger.log(.info, "-> \(inputFilelistPath)".lightMagenta)

        let outputFilelistPath = configuration.outputPath + "WeaverOutput.xcfilelist"
        try outputFilelistPath.parent().mkpath()
        try outputFilelistPath.write(filelists.output)
        Logger.log(.info, "-> \(outputFilelistPath)".lightMagenta)

        Logger.log(.info, "Done".lightMagenta, benchmark: .end("writing"))
        Logger.log(.info, "")
    }
}

main.run(version)
