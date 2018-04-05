//
//  main.swift
//  BeaverDICommand
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation
import Commander
import BeaverDICodeGen
import SourceKittenFramework
import Darwin
import PathKit

let main = command(

    Option<String>("output_path", ".", description: "Where the swift files will be generated."),
    Option<TemplatePathArgument>("template_path", TemplatePathArgument(), description: "Custom template path."),
    Flag("safe", default: true),
    Argument<InputPathsArgument>("input_paths", description: "Swift files to parse.")

) { outputPath, templatePath, safeFlag, inputPaths in

    do {
        let generator = try Generator(template: templatePath.value)

        Logger.log(.info, "Parsing...")
        
        var dataToWrite: [(path: Path, data: String)] = []
        var syntaxTrees: [Expr] = []
        
        for filePath in inputPaths.values {
            guard let file = File(path: filePath.string) else {
                return
            }
            
            Logger.log(.info, "<- '\(filePath)'")
            let tokens = try Lexer(file, fileName: filePath.string).tokenize()
            let ast = try Parser(tokens, fileName: filePath.string).parse()

            if safeFlag {
                syntaxTrees.append(ast)
            }
            
            guard let fileName = filePath.components.last else {
                Logger.log(.error, "Could not retrieve file name from path '\(filePath)'")
                return
            }
            let generatedFilePath = Path(outputPath) + "BeaverDI.\(fileName)"
 
            guard let generatedString = try generator.generate(from: ast) else {
                Logger.log(.info, "-- No BeaverDI annotation found in file '\(filePath)'.")
                continue
            }
            
            dataToWrite.append((generatedFilePath, generatedString))
        }

        if safeFlag {
            Logger.log(.info, "")
            Logger.log(.info, "Checking dependency graph...")
            
            let inspector = try Inspector(syntaxTrees: syntaxTrees)
            try inspector.validate()
        }
        
        Logger.log(.info, "")
        Logger.log(.info, "Writing...")
        
        for (path, data) in dataToWrite {
            try path.write(data)
            Logger.log(.info, "-> '\(path)'")
        }

        Logger.log(.info, "")
        Logger.log(.info, "Done.")
        
    } catch {
        Logger.log(.error, "\(error)")
        exit(1)
    }
}

main.run()
