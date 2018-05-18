//
//  Error.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import Weaver

enum TokenError: Error, AutoEquatable {
    case invalidAnnotation(String)
    case invalidScope(String)
    case invalidCustomRefValue(String)
    case invalidConfigurationAttributeValue(value: String, expected: String)
}

enum LexerError: Error, AutoEquatable {
    case invalidAnnotation(line: Int, file: String, underlyingError: TokenError)
}

enum ParserError: Error, AutoEquatable {
    case unexpectedToken(line: Int, file: String)
    case unexpectedEOF(file: String)
    
    case unknownDependency(line: Int, file: String, dependencyName: String)
    case depedencyDoubleDeclaration(line: Int, file: String, dependencyName: String)
    case configurationAttributeDoubleAssignation(line: Int, file: String, attribute: ConfigurationAttribute)
}

enum GeneratorError: Error, AutoEquatable {
    case invalidTemplatePath(path: String)
}

enum InspectorError: Error, AutoEquatable {
    case invalidAST(unexpectedExpr: Expr, file: String?)
    case invalidGraph(line: Int, file: String, dependencyName: String, typeName: String?, underlyingError: InspectorAnalysisError)
}

enum InspectorAnalysisError: Error, AutoEquatable {
    case cyclicDependency
    case unresolvableDependency(history: [InspectorAnalysisHistoryRecord])
    case isolatedResolverCannotHaveReferents
}

enum InspectorAnalysisHistoryRecord: AutoEquatable {
    case foundUnaccessibleDependency(line: Int, file: String, name: String, typeName: String?)
    case couldNotFindDependencyInResolver(line: Int?, file: String?, name: String, typeName: String?)
}

// MARK: - Description

extension TokenError: CustomStringConvertible {

    var description: String {
        switch self {
        case .invalidAnnotation(let annotation):
            return "Invalid annotation: '\(annotation)'"
        case .invalidScope(let scope):
            return "Invalid scope: '\(scope)'"
        case .invalidCustomRefValue(let value):
            return "Invalid customRef value: \(value). Expected true|false."
        case .invalidConfigurationAttributeValue(let value, let expected):
            return "Invlid configuration attribute value: \(value). Expected \(expected)."
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
            return printableError(line, file, "Unexpected token")
        case .unknownDependency(let line, let file, let dependencyName):
            return printableError(line, file, "Unknown dependency: '\(dependencyName)'")
        case .configurationAttributeDoubleAssignation(let line, let file, let attribute):
            return printableError(line, file, "Configuration attribute '\(attribute.name)' was already set")
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
            var description = printableError(line, file, "Invalid graph because of issue: \(underlyingIssue): with '\(dependencyName): \(typeName ?? "_")'")
            if let history = underlyingIssue.history {
                description = ([description] + history.map { $0.description }).joined(separator: "\n")
            }
            return description
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
        case .isolatedResolverCannotHaveReferents:
            return "Isolated resolver cannot have referents"
        }
    }
    
    fileprivate var history: [InspectorAnalysisHistoryRecord]? {
        switch self {
        case .cyclicDependency,
             .isolatedResolverCannotHaveReferents:
            return nil
        case .unresolvableDependency(let history):
            return history
        }
    }
}

extension InspectorAnalysisHistoryRecord: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .couldNotFindDependencyInResolver(let line, let file, let name, let typeName):
            return printableWarning(line, file, "Could not find the dependency '\(name)' in '\(typeName ?? "_")'. You may want to register it here to solve this issue.")
        case .foundUnaccessibleDependency(let line, let file, let name, let typeName):
            return printableWarning(line, file, "Found unaccessible dependency '\(name)' in '\(typeName ?? "_")'. You may want to set its scope to '.container' or '.weak' to solve this issue")
        }
    }
}

// MARK: - Utils

private func printableError(_ line: Int, _ file: String, _ message: String) -> String {
    return "\(file):\(line + 1): error: \(message)."
}

private func printableWarning(_ line: Int?, _ file: String?, _ message: String) -> String {
    if let line = line, let file = file {
        return "\(file):\(line + 1): warning: \(message)."
    } else {
        return "warning: \(message)."
    }
}
