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
    Argument<InputPathsArgument>("input_paths", description: "Swift files to parse.")

) { outputPath, inputPaths in

    let generator = Generator(template: "dependency_resolver")

    do {
        Logger.log(.info, "Parsing...")
        
        var dataToWrite: [(path: Path, data: String)] = []
        
        for filePath in inputPaths.values {
            guard let file = File(path: filePath) else {
                return
            }
            
            guard let fileName = filePath.split(separator: "/").last else {
                Logger.log(.error, "Could not retrieve file name from path '\(filePath)'")
                return
            }
            
            Logger.log(.info, "<- '\(filePath)'")
            let tokens = try Lexer(file).tokenize()
            let ast = try Parser(tokens).parse()
            
            let generatedFilePath = Path(outputPath + "/beaverdi." + fileName)
            let generatedString = try generator.generate(from: ast)
 
            dataToWrite += [(generatedFilePath, generatedString)]
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
        Logger.log(.error, "Error: \(error)")
    }
}

main.run()
