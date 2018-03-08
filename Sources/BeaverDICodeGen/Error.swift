//
//  Error.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation

enum TokenError: Swift.Error {
    case invalidAnnotation(String)
    case invalidScope(String)
}

enum LexerError: Swift.Error {
    case invalidAnnotation(line: Int, underlyingError: TokenError)
}

enum ParserError: Swift.Error {
    case unexpectedToken(line: Int)
    case unexpectedEOF
    
    case unknownDependency(line: Int, dependencyName: String)
    case missingDependency(line: Int, typeName: String)
    case depedencyDoubleDeclaration(line: Int, dependencyName: String)
}

// MARK: - Description

extension TokenError: CustomStringConvertible {

    var description: String {
        switch self {
        case .invalidAnnotation(let annotation):
            return "Invalid annotation: '\(annotation)'"
        case .invalidScope(let scope):
            return "Invalid scope: '\(scope)'"
        }
    }
}

extension LexerError: CustomStringConvertible {

    var description: String {
        switch self {
        case .invalidAnnotation(let line, let underlyingError):
            return "\(underlyingError): \(printableLine(line))."
        }
    }
}

extension ParserError: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .depedencyDoubleDeclaration(let line, let dependencyName):
            return "Double dependency declaration: '\(dependencyName)': \(printableLine(line))."
        case .missingDependency(let line, let typeName):
            return "Missing dependency declaration for type: '\(typeName)': \(printableLine(line))."
        case .unexpectedEOF:
            return "Unexpected EOF (End of file)."
        case .unexpectedToken(let line):
            return "Unexpected token at line: \(printableLine(line))."
        case .unknownDependency(let line, let dependencyName):
            return "Unknown dependency: '\(dependencyName)': at line \(printableLine(line))."
        }
    }
}

// MARK: - Utils

private func printableLine(_ line: Int) -> String {
    return "at line \(line + 1)"
}
