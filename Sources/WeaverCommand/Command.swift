//
//  Command.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 12/7/19.
//

import Foundation
import Commander
import WeaverCodeGen
import SourceKittenFramework
import Darwin
import PathKit
import Rainbow

private let version = "1.0.6"

// MARK: - Linker

private extension Linker {

    convenience init(_ inputPaths: [Path],
                     cachePath: Path,
                     shouldLog: Bool = true) throws {
        
        var didChange = false
        try self.init(inputPaths,
                      cachePath: cachePath,
                      shouldLog: shouldLog,
                      didChange: &didChange)
        _ = didChange
    }
    
    convenience init(_ inputPaths: [Path],
                     cachePath: Path,
                     shouldLog: Bool = true,
                     didChange: inout Bool) throws {

        // ---- Read Cache ----

        if shouldLog {
            Logger.log(.info, "")
            Logger.log(.info, "Reading cache...".yellow, benchmark: .start("caching"))
        }
        let lexerCache = LexerCache(for: cachePath, version: version, shouldLog: shouldLog)
        if shouldLog { Logger.log(.info, "Done".yellow, benchmark: .end("caching")) }

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
            let tokens = try Lexer(file, fileName: filePath.string, cache: lexerCache).tokenize()
            return try Parser(tokens, fileName: filePath.string).parse()
        }
        if shouldLog { Logger.log(.info, "Done".yellow, benchmark: .end("parsing")) }
        
        // ---- Write Cache ----
        
        if shouldLog {
            Logger.log(.info, "")
            Logger.log(.info, "Writing cache to disk...".yellow, benchmark: .start("caching"))
        }
        didChange = lexerCache.didChange
        lexerCache.saveToDisk()
        if shouldLog { Logger.log(.info, "Done".yellow, benchmark: .end("caching")) }

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
    static let projectPath = Option<Path?>("project-path", default: nil, description: "Project's directory.")
    static let configPath = Option<Path?>("config-path", default: nil, description: "Configuration path.")
    static let mainOutputPath = Option<Path?>("main-output-path", default: nil, description: "Where the main swift files will be generated.")
    static let testsOutputPath = Option<Path?>("tests-output-path", default: nil, description: "Where the tests swift files will be generated.")
    static let inputPath = VariadicOption<String>("input-path", default: [], description: "Paths to input files.")
    static let ignoredPath = VariadicOption<String>("ignored-path", default: [], description: "Paths to ignore.")
    static let cachePath = Option<Path?>("cache-path", default: nil, description: "Cache path.")
    static let recursiveOff = OptionalFlag("recursive-off", disabledName: "recursive-on")
    static let pretty = Flag("pretty", default: false)
    static let tests = OptionalFlag("tests", default: nil)
    static let testableImports = VariadicOption<String>("testable-imports", default: [], description: "Modules to import for testing.")
    static let swiftlintDisableAll = OptionalFlag("swiftlint-disable-all", default: nil)
}

// MARK: - Commands

public let weaverCommand = Group {
    
    $0.command(
        "swift",
        Parameters.projectPath,
        Parameters.configPath,
        Parameters.mainOutputPath,
        Parameters.testsOutputPath,
        Parameters.inputPath,
        Parameters.ignoredPath,
        Parameters.cachePath,
        Parameters.recursiveOff,
        Parameters.tests,
        Parameters.testableImports,
        Parameters.swiftlintDisableAll)
    {
        projectPath,
        configPath,
        mainOutputPath,
        testsOutputPath,
        inputPaths,
        ignoredPaths,
        cachePath,
        recursiveOff,
        tests,
        testableImports,
        swiftlintDisableAll in

        let configuration = try Configuration(
            configPath: configPath,
            inputPathStrings: inputPaths.isEmpty ? nil : inputPaths,
            ignoredPathStrings: ignoredPaths.isEmpty ? nil : ignoredPaths,
            projectPath: projectPath,
            mainOutputPath: mainOutputPath,
            testsOutputPath: testsOutputPath,
            cachePath: cachePath,
            recursiveOff: recursiveOff,
            tests: tests,
            testableImports: testableImports.isEmpty ? nil : testableImports,
            swiftlintDisableAll: swiftlintDisableAll
        )

        let mainOutputPath = configuration.mainOutputPath
        let testsOutputPath = configuration.testsOutputPath
        
        do {
            Logger.log(.info, "Let the injection begin.".lightRed, benchmark: .start("all"))

            // ---- Link ----
            
            Logger.log(.info, "Listing files...".yellow, benchmark: .start("listing"))
            let inputPaths = try configuration.inputPaths()
            Logger.log(.info, "Done".yellow, benchmark: .end("listing"))

            var didChange = false
            let linker = try Linker(inputPaths, cachePath: configuration.cachePath, didChange: &didChange)
            let dependencyGraph = linker.dependencyGraph

            // ---- Inspect ----
            
            Logger.log(.info, "")
            Logger.log(.info, "Checking dependency graph...".magenta, benchmark: .start("checking"))
                
            let inspector = Inspector(dependencyGraph: dependencyGraph)
            try inspector.validate()
            
            Logger.log(.info, "Done".magenta, benchmark: .end("checking"))

            // ---- Generate ----

            Logger.log(.info, "")
            Logger.log(.info, "Generating boilerplate code...".lightBlue, benchmark: .start("generating"))

            let generator = try SwiftGenerator(
                dependencyGraph: dependencyGraph,
                inspector: inspector,
                version: version,
                testableImports: configuration.testableImports,
                swiftlintDisableAll: configuration.swiftlintDisableAll
            )

            let mainGeneratedData = try generator.generate()
            let testsGeneratedData = configuration.tests ? try generator.generateTests() : nil

            Logger.log(.info, "Done".lightBlue, benchmark: .end("generating"))

            // ---- Write ----

            Logger.log(.info, "")
            Logger.log(.info, "Writing...".lightMagenta, benchmark: .start("writing"))
            
            if didChange || mainOutputPath.exists == false || (testsOutputPath.exists == false && configuration.tests) {
                let dataToWrite = [
                    (mainOutputPath, mainGeneratedData),
                    (testsOutputPath, testsGeneratedData)
                ]

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
            } else {
                Logger.log(.info, "No change detected. Nothing to write to disk.".lightMagenta, benchmark: .end("writing"))
            }

            Logger.log(.info, "")
            Logger.log(.info, "Injection done in \(dependencyGraph.injectableTypesCount) different types".lightWhite, benchmark: .end("all"))
        } catch {
            Logger.log(.error, "\(error)")
            exit(1)
        }
    }
    
    $0.command(
        "clean",
        Parameters.projectPath,
        Parameters.configPath,
        Parameters.cachePath
    ) {
        projectPath,
        configPath,
        cachePath in
        
        let configuration = try Configuration(configPath: configPath,
                                              projectPath: projectPath,
                                              cachePath: cachePath)
        
        let lexerCache = LexerCache(for: configuration.cachePath, version: version)
        lexerCache.clear()
        lexerCache.saveToDisk()
    }
    
    $0.command(
        "json",
        Parameters.projectPath,
        Parameters.configPath,
        Parameters.pretty,
        Parameters.inputPath,
        Parameters.ignoredPath,
        Parameters.cachePath,
        Parameters.recursiveOff,
        Parameters.swiftlintDisableAll
    ) {
        projectPath,
        configPath,
        pretty,
        inputPaths,
        ignoredPaths,
        cachePath,
        recursiveOff,
        swiftlintDisableAll in
        
        let configuration = try Configuration(
            configPath: configPath,
            inputPathStrings: inputPaths.isEmpty ? nil : inputPaths,
            ignoredPathStrings: ignoredPaths.isEmpty ? nil : ignoredPaths,
            projectPath: projectPath,
            cachePath: cachePath,
            recursiveOff: recursiveOff,
            swiftlintDisableAll: swiftlintDisableAll
        )
        
        // ---- Link ----

        let linker = try Linker(try configuration.inputPaths(),
                                cachePath: configuration.cachePath,
                                shouldLog: false)
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
    
    $0.command("version") {
        print(version)
    }
}

