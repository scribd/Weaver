//
//  Expr.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

public indirect enum Expr: AutoEquatable {
    case file(types: [Expr], name: String)
    case typeDeclaration(TokenBox<InjectableType>, config: [TokenBox<ConfigurationAnnotation>], children: [Expr])
    case registerAnnotation(TokenBox<RegisterAnnotation>)
    case scopeAnnotation(TokenBox<ScopeAnnotation>)
    case referenceAnnotation(TokenBox<ReferenceAnnotation>)
    case customRefAnnotation(TokenBox<CustomRefAnnotation>)
    case parameterAnnotation(TokenBox<ParameterAnnotation>)
}

// MARK: - Description

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .file(let types, let name):
            return """
            File[\(name)]
            \(types.map { " \($0)" }.joined(separator: "\n"))
            """
        case .registerAnnotation(let token):
            return "Register - \(token)"
        case .scopeAnnotation(let token):
            return "Scope - \(token)"
        case .typeDeclaration(let type, let config, let children):
            return """
            \(type)
            \(config.map { "   \($0)" }.joined(separator: "\n"))
            \(children.map { "   \($0)" }.joined(separator: "\n"))
            """
        case .referenceAnnotation(let token):
            return "Reference - \(token)"
        case .customRefAnnotation(let token):
            return "CustomRef - \(token)"
        case .parameterAnnotation(let token):
            return "Parameter - \(token)"
        }
    }
}

// MARK: - Sequence

struct ExprSequence: Sequence, IteratorProtocol {
    
    private var stack: [[Expr]]
    
    init(exprs: [Expr]) {
        self.stack = [exprs]
    }
    
    mutating func next() -> Expr? {
        guard let exprs = stack.popLast() else {
            return nil
        }

        guard let expr = exprs.first else {
            return next()
        }

        var mutableExprs = exprs
        mutableExprs.removeFirst()
        stack.append(mutableExprs)
        
        switch expr {
        case .file(let exprs, _),
             .typeDeclaration(_, _, let exprs):
            stack.append(exprs)
        
        case .referenceAnnotation,
             .registerAnnotation,
             .scopeAnnotation,
             .customRefAnnotation,
             .parameterAnnotation:
            break
        }
        
        return expr
    }
}
