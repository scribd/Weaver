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

struct InputPaths: ArgumentConvertible {
    
    let values: [String]

    init(parser: ArgumentParser) throws {
        guard !parser.isEmpty else {
            throw ArgumentError.missingValue(argument: "input_paths")
        }
        
        var values: [String] = []
        
        while let value = parser.shift() {
            values += [value]
        }
        
        self.values = values
    }
    
    var description: String {
        return values.description
    }
}

let main = command(

    Option<String>("output_path", ".", description: "Where the swift files will be generated."),
    Argument<InputPaths>("input_paths", description: "Swift files to parse.")

) { outputPath, inputPaths in

    let generator = Generator(template: "dependency_resolver")

    do {
        for filePath in inputPaths.values {
            guard let file = File(path: filePath) else {
                return
            }
            
            guard let fileName = filePath.split(separator: "/").last else {
                fputs("Could not retrieve file name from path '\(filePath)'", __stderrp)
                return
            }
            
            print("Parsing \(filePath)...")
            let tokens = try Lexer(file).tokenize()
            let ast = try Parser(tokens).parse()
            
            let generatedFilePath = Path(outputPath + "/beaverdi." + fileName)
            let generatedString = try generator.generate(from: ast)
 
            print("Writing \(generatedFilePath)...")
            try generatedFilePath.write(generatedString)
        }

        print("Done.")
        
    } catch {
        fputs(error.localizedDescription, __stderrp)
    }
}

main.run()
