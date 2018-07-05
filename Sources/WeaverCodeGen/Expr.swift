//
//  Expr.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

// MARK: Expressions

public indirect enum Expr: AutoEquatable {
    case file(types: [Expr], name: String, imports: [String])
    case typeDeclaration(TokenBox<InjectableType>, children: [Expr])
    case registerAnnotation(TokenBox<RegisterAnnotation>)
    case scopeAnnotation(TokenBox<ScopeAnnotation>)
    case referenceAnnotation(TokenBox<ReferenceAnnotation>)
    case parameterAnnotation(TokenBox<ParameterAnnotation>)
    case configurationAnnotation(TokenBox<ConfigurationAnnotation>)
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
        case .file(let exprs, _, _),
             .typeDeclaration(_, let exprs):
            stack.append(exprs)
            
        case .referenceAnnotation,
             .registerAnnotation,
             .scopeAnnotation,
             .parameterAnnotation,
             .configurationAnnotation:
            break
        }
        
        return expr
    }
}

// MARK: - Description

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .file(let types, let name, _):
            return """
            File[\(name)]
            \(types.map { " \($0)" }.joined(separator: "\n"))
            """
        case .registerAnnotation(let token):
            return "Register - \(token)"
        case .scopeAnnotation(let token):
            return "Scope - \(token)"
        case .typeDeclaration(let type, let children):
            return """
            \(type)
            \(children.map { "   \($0)" }.joined(separator: "\n"))
            """
        case .referenceAnnotation(let token):
            return "Reference - \(token)"
        case .parameterAnnotation(let token):
            return "Parameter - \(token)"
        case .configurationAnnotation(let token):
            return "Configuration - \(token)"
        }
    }
}

// MARK: - Convenience

extension Expr {
    
    func toFile() -> (types: [Expr], name: String, imports: [String])? {
        switch self {
        case .file(let types, let name, let imports):
            return (types, name, imports)
        default:
            return nil
        }
    }
    
    func toTypeDeclaration() -> (token: TokenBox<InjectableType>, children: [Expr])? {
        switch self {
        case .typeDeclaration(let token, let children):
            return (token, children)
        default:
            return nil
        }
    }
    
    func toReferenceAnnotation() -> TokenBox<ReferenceAnnotation>? {
        switch self {
        case .referenceAnnotation(let token):
            return token
        default:
            return nil
        }
    }
}

extension ExprSequence {

    var referenceAnnotations: [TokenBox<ReferenceAnnotation>] {
        return compactMap {$0.toReferenceAnnotation() }
    }
}
