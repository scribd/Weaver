//
//  Error.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import Weaver

enum TokenError: Error {
    case invalidAnnotation(String)
    case invalidScope(String)
    case invalidCustomRefValue(String)
}

enum LexerError: Error {
    case invalidAnnotation(line: Int, file: String, underlyingError: TokenError)
}

enum ParserError: Error {
    case unexpectedToken(line: Int, file: String)
    case unexpectedEOF(file: String)
    
    case unknownDependency(line: Int, file: String, dependencyName: String)
    case depedencyDoubleDeclaration(line: Int, file: String, dependencyName: String)
}

enum GeneratorError: Error {
    case invalidTemplatePath(path: String)
}

enum InspectorError: Error {
    case invalidAST(unexpectedExpr: Expr, file: String?)
    case invalidGraph(line: Int, file: String, dependencyName: String, typeName: String?, underlyingError: InspectorAnalysisError)
}

enum InspectorAnalysisError: Error {
    case cyclicDependency
    case unresolvableDependency
}

// MARK: - Description

extension TokenError: CustomStringConvertible {

    // <filename>:<linenumber>: error | warn | note : <message>\n
    
    var description: String {
        switch self {
        case .invalidAnnotation(let annotation):
            return "Invalid annotation: '\(annotation)'"
        case .invalidScope(let scope):
            return "Invalid scope: '\(scope)'"
        case .invalidCustomRefValue(let value):
            return "Invalid customRef value: \(value). Expected true|false."
        }
    }
}

extension LexerError: CustomStringConvertible {

    var description: String {
        switch self {
        case .invalidAnnotation(let line, let file, let underlyingError):
            return printableError(line, file, "\(underlyingError)")
        }
    }
}

extension ParserError: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .depedencyDoubleDeclaration(let line, let file, let dependencyName):
            return printableError(line, file, "Double dependency declaration: '\(dependencyName)'")
        case .unexpectedEOF(let file):
            return printableError(0, file, "Unexpected EOF (End of file)")
        case .unexpectedToken(let line, let file):
            return printableError(line, file, "Unexpected token at line")
        case .unknownDependency(let line, let file, let dependencyName):
            return printableError(line, file, "Unknown dependency: '\(dependencyName)'")
        }
    }
}

extension GeneratorError: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .invalidTemplatePath(let path):
            return "Invalid template path: \(path)."
        }
    }
}

extension InspectorError: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .invalidAST(let token, let file):
            return "Invalid AST because of token: \(token)" + (file.flatMap { ": in file \($0)." } ?? ".")
        case .invalidGraph(let line, let file, let dependencyName, let typeName, let underlyingIssue):
            return printableError(line, file, "Invalid graph because of issue: \(underlyingIssue): with '\(dependencyName): \(typeName ?? "_")'")
        }
    }
}

extension InspectorAnalysisError: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .cyclicDependency:
            return "Cyclic dependency"
        case .unresolvableDependency:
            return "Unresolvable dependency"
        }
    }
}

// MARK: - Utils

private func printableError(_ line: Int, _ file: String, _ message: String) -> String {
    return "\(file):\(line + 1): error: \(message)."
}

// MARK: - Equatable

extension TokenError: Equatable {
    
    static func ==(lhs: TokenError, rhs: TokenError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAnnotation(let lAnnotation), .invalidAnnotation(let rAnnotation)):
            return lAnnotation == rAnnotation
        case (.invalidScope(let lScope), .invalidScope(let rScope)):
            return lScope == rScope
        case (.invalidCustomRefValue(let lValue), .invalidCustomRefValue(let rValue)):
            return lValue == rValue
        case (.invalidAnnotation, _),
             (.invalidScope, _),
             (.invalidCustomRefValue, _):
            return false
        }
    }
}

extension LexerError: Equatable {

    static func ==(lhs: LexerError, rhs: LexerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAnnotation(let lAnnotation), .invalidAnnotation(let rAnnotation)):
            return lAnnotation == rAnnotation
        }
    }
}

extension ParserError: Equatable {

    static func ==(lhs: ParserError, rhs: ParserError) -> Bool {
        switch (lhs, rhs) {
        case (.depedencyDoubleDeclaration(let lLine, let lFile, let lDependencyName), .depedencyDoubleDeclaration(let rLine, let rFile, let rDependencyName)),
             (.unknownDependency(let lLine, let lFile, let lDependencyName), .unknownDependency(let rLine, let rFile, let rDependencyName)):
            guard lLine == rLine else { return false }
            guard lFile == rFile else { return false }
            guard lDependencyName == rDependencyName else { return false }
            return true
            
        case (.unexpectedEOF, .unexpectedEOF):
            return true
            
        case (.unexpectedToken(let lLine), .unexpectedToken(let rLine)):
            return lLine == rLine
            
        case (.depedencyDoubleDeclaration, _),
             (.unknownDependency, _),
             (.unexpectedEOF, _),
             (.unexpectedToken, _):
            return false
        }
    }
}

extension InspectorError: Equatable {
    
    static func ==(lhs: InspectorError, rhs: InspectorError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAST(let lToken, let lFile), .invalidAST(let rToken, let rFile)):
            guard lToken == rToken else { return false }
            guard lFile == rFile else { return false }
            return true

        case (.invalidGraph(let lLine, let lFile, let lDependencyName, let lTypeName, let lUnderlyingIssue),
              .invalidGraph(let rLine, let rFile, let rDependencyName, let rTypeName, let rUnderlyingIssue)):
            guard lLine == rLine else { return false }
            guard lFile == rFile else { return false }
            guard lDependencyName == rDependencyName else { return false }
            guard lTypeName == rTypeName else { return false }
            guard lUnderlyingIssue == rUnderlyingIssue else { return false }
            return true
        
        case (.invalidAST, _),
             (.invalidGraph, _):
            return false
        }
    }
}

extension InspectorAnalysisError: Equatable {
    
    static func ==(lhs: InspectorAnalysisError, rhs: InspectorAnalysisError) -> Bool {
        switch (lhs, rhs) {
        case (.cyclicDependency, .cyclicDependency),
             (.unresolvableDependency, .unresolvableDependency):
            return true
        
        case (.cyclicDependency, _),
             (.unresolvableDependency, _):
            return false
        }
    }
}
