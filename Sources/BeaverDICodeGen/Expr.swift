//
//  Expr.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

indirect enum Expr {
    case typeDeclaration(parentResolver: Token<ParentResolverAnnotation>, children: [Expr])
    case registerAnnotation(Token<RegisterAnnotation>)
    case scopeAnnotation(Token<ScopeAnnotation>)
}

// MARK: - Equatable

extension Expr: Equatable {
    static func ==(lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.typeDeclaration(let lParentResolver, let lChildren), .typeDeclaration(let rParentResolver, let rChildren)):
            guard lParentResolver == rParentResolver else { return false }
            guard lChildren.elementsEqual(rChildren) else { return false }
            return true
        case (.registerAnnotation(let lhs), .registerAnnotation(let rhs)):
            return lhs == rhs
        case (.scopeAnnotation(let lhs), .scopeAnnotation(let rhs)):
            return lhs == rhs
        case (.typeDeclaration, _),
             (.registerAnnotation, _),
             (.scopeAnnotation, _):
            return false
        }
    }
}

// MARK: - Description

extension Expr: CustomStringConvertible {
    var description: String {
        switch self {
        case .registerAnnotation(let token):
            return "Register - \(token)"
        case .scopeAnnotation(let token):
            return "Scope - \(token)"
        case .typeDeclaration(let token, let children):
            return "Type - \(token)\n" + children.map { "  \($0)" }.joined(separator: "\n")
        }
    }
}
