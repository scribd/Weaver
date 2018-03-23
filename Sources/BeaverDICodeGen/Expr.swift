//
//  Expr.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

public indirect enum Expr {
    case file(types: [Expr], name: String)
    case typeDeclaration(TokenBox<InjectableType>, children: [Expr])
    case registerAnnotation(TokenBox<RegisterAnnotation>)
    case scopeAnnotation(TokenBox<ScopeAnnotation>)
    case referenceAnnotation(TokenBox<ReferenceAnnotation>)
}

// MARK: - Equatable

extension Expr: Equatable {
    public static func ==(lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.file(let lTypes, let lName), .file(let rTypes, let rName)):
            guard lTypes.elementsEqual(rTypes) else { return false }
            guard lName == rName else { return false }
            return true
        case (.typeDeclaration(let lToken, let lChildren), .typeDeclaration(let rToken, let rChildren)):
            guard lToken == rToken else { return false }
            guard lChildren.elementsEqual(rChildren) else { return false }
            return true
        case (.registerAnnotation(let lhs), .registerAnnotation(let rhs)):
            return lhs == rhs
        case (.scopeAnnotation(let lhs), .scopeAnnotation(let rhs)):
            return lhs == rhs
        case (.referenceAnnotation(let lhs), .referenceAnnotation(let rhs)):
            return lhs == rhs
        case (.file, _),
             (.typeDeclaration, _),
             (.registerAnnotation, _),
             (.scopeAnnotation, _),
             (.referenceAnnotation, _):
            return false
        }
    }
}

// MARK: - Description

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .file(let types, let name):
            return "File[\(name)]\n\n" + types.map { "\($0)" }.joined(separator: "\n")
        case .registerAnnotation(let token):
            return "Register - \(token)"
        case .scopeAnnotation(let token):
            return "Scope - \(token)"
        case .typeDeclaration(let type, let children):
            return "\(type)\n" + children.map { "  \($0)" }.joined(separator: "\n")
        case .referenceAnnotation(let token):
            return "Reference - \(token)"
        }
    }
}
