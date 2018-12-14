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

// MARK: - Linker

private extension Linker {

    convenience init(_ inputPaths: [String], shouldLog: Bool = true) throws {

        // ---- Parse ----

        if shouldLog {
            Logger.log(.info, "")
            Logger.log(.info, "Parsing...".yellow, benchmark: .start("parsing"))
        }
        let asts: [Expr] = try inputPaths.compactMap { filePath in
            guard let file = File(path: filePath) else {
                return nil
            }
            
            if shouldLog { Logger.log(.info, "<- '\(filePath)'".yellow) }
            let tokens = try Lexer(file, fileName: filePath).tokenize()
            return try Parser(tokens, fileName: filePath).parse()
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

// MARK: - Commands

let main = Group {
    $0.command(
        "generate",
        Option<String>("output_path", default: ".", description: "Where the swift files will be generated."),
        Option<TemplatePathArgument>("template_path", default: TemplatePathArgument(), description: "Custom template path."),
        Flag("unsafe", default: false),
        Flag("single_output", default: false),
        Argument<InputPathsArgument>("input_paths", description: "Swift files to parse.")
    ) { outputPath, templatePath, unsafeFlag, singleOutput, inputPaths in
        
        do {
            
            Logger.log(.info, "Let the injection begin.".lightRed, benchmark: .start("all"))

            // ---- Link ----

            let linker = try Linker(inputPaths.values.map { $0.string })
            let dependencyGraph = linker.dependencyGraph
            
            // ---- Generate ----

            Logger.log(.info, "")
            Logger.log(.info, "Generating boilerplate code...".lightBlue, benchmark: .start("generating"))
            let generator = try Generator(dependencyGraph: dependencyGraph, template: templatePath.value)
            let generatedData = try generator.generate()
            Logger.log(.info, "Done".lightBlue, benchmark: .end("generating"))
            
            // ---- Collect ----
            
            let dataToWrite: [(path: Path, data: String?)] = generatedData.compactMap { (file, data) in

                let filePath = Path(file)

                guard let fileName = filePath.components.last else {
                    Logger.log(.error, "Could not retrieve file name from path '\(filePath)'".red)
                    return nil
                }
                let generatedFilePath = Path(outputPath) + "Weaver.\(singleOutput ? "swift" : fileName)"
                
                guard let data = data else {
                    Logger.log(.info, "-- No Weaver annotation found in file '\(filePath)'.".red)
                    return (path: generatedFilePath, data: nil)
                }

                return (path: generatedFilePath, data: data)
            }
            
            // ---- Inspect ----

            if !unsafeFlag {
                Logger.log(.info, "")
                Logger.log(.info, "Checking dependency graph...".magenta, benchmark: .start("checking"))
                
                let inspector = Inspector(dependencyGraph: dependencyGraph)
                try inspector.validate()
                
                Logger.log(.info, "Done".magenta, benchmark: .end("checking"))
            }
            
            // ---- Write ----
            
            Logger.log(.info, "")
            Logger.log(.info, "Writing...".lightMagenta, benchmark: .start("writing"))
            
            if singleOutput {
                let (path, data) = dataToWrite.reduce((nil, nil)) {
                    ($1.0, "\($0.1 ?? String())\n\n// --------------------------------------------\n\n\($1.1 ?? String())")
                }
                if let path = path, let data = data {
                    try path.write(data)
                    Logger.log(.info, "-> '\(path)'".lightMagenta)
                }
            } else {
                for (path, data) in dataToWrite {
                    if let data = data {
                        try path.write(data)
                        Logger.log(.info, "-> '\(path)'".lightMagenta)
                    } else if path.isFile && path.isDeletable {
                        try path.delete()
                        Logger.log(.info, " X '\(path)'".lightMagenta)
                    }
                }
            }
            Logger.log(.info, "Done".lightMagenta, benchmark: .end("writing"))
            Logger.log(.info, "")
            Logger.log(.info, "Injection done in \(dependencyGraph.injectableTypesCount) different types".lightWhite, benchmark: .end("all"))

        } catch {
            Logger.log(.error, "\(error)".red)
            exit(1)
        }
    }
    
    $0.command(
        "export",
        Flag("pretty", default: false),
        Argument<InputPathsArgument>("input_paths", description: "Swift files to parse.")
    ) { pretty, inputPaths in
        do {
            // ---- Link ----
            
            let linker = try Linker(inputPaths.values.map { $0.string }, shouldLog: false)
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
        } catch {
            Logger.log(.error, "\(error)")
            exit(1)
        }
    }
}

main.run("0.11.2")
