//
//  Error.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation

enum TokenError: Error {
    case invalidAnnotation(String)
    case invalidScope(String)
}

enum LexerError: Error {
    case invalidAnnotation(line: Int, underlyingError: TokenError)
}

enum ParserError: Error {
    case unexpectedToken(line: Int)
    case unexpectedEOF
    
    case unknownDependency(line: Int, dependencyName: String)
    case depedencyDoubleDeclaration(line: Int, dependencyName: String)
}

enum GeneratorError: Error {
    case invalidTemplatePath(path: String)
}

enum InspectorError: Error {
    case invalidAST(unexpectedExpr: Expr)
    case invalidGraph(line: Int, dependencyName: String, typeName: String, underlyingIssue: InspectorAnalysisError)
}

enum InspectorAnalysisError: Error {
    case cyclicDependency
    case unresolvableDependency
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
        case .unexpectedEOF:
            return "Unexpected EOF (End of file)."
        case .unexpectedToken(let line):
            return "Unexpected token at line: \(printableLine(line))."
        case .unknownDependency(let line, let dependencyName):
            return "Unknown dependency: '\(dependencyName)': at line \(printableLine(line))."
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
        case .invalidAST(let token):
            return "Invalid AST because of token: \(token)."
        case .invalidGraph(let line, let dependencyName, let typeName, let underlyingIssue):
            return "Invalid graph because of issue: \(underlyingIssue): with the dependency '\(dependencyName): \(typeName)' at line \(printableLine(line))."
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

private func printableLine(_ line: Int) -> String {
    return "at line \(line + 1)"
}

// MARK: - Equatable

extension TokenError: Equatable {
    
    static func ==(lhs: TokenError, rhs: TokenError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAnnotation(let lAnnotation), .invalidAnnotation(let rAnnotation)):
            return lAnnotation == rAnnotation
        case (.invalidScope(let lScope), .invalidScope(let rScope)):
            return lScope == rScope
        case (.invalidAnnotation, _),
             (.invalidScope, _):
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
        case (.depedencyDoubleDeclaration(let lLine, let lDependencyName), .depedencyDoubleDeclaration(let rLine, let rDependencyName)),
             (.unknownDependency(let lLine, let lDependencyName), .unknownDependency(let rLine, let rDependencyName)):
            guard lLine == rLine else { return false }
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
        case (.invalidAST(let lToken), .invalidAST(let rToken)):
            return lToken == rToken
        case (.invalidGraph(let lLine, let lDependencyName, let lTypeName, let lUnderlyingIssue),
              .invalidGraph(let rLine, let rDependencyName, let rTypeName, let rUnderlyingIssue)):
            guard lLine == rLine else { return false }
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
