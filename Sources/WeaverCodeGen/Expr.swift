//
//  Expr.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

// MARK: Expressions

public indirect enum Expr: Equatable {
    case file(types: [Expr], name: String, imports: [String])
    case typeDeclaration(TokenBox<InjectableType>, children: [Expr])
    case registerAnnotation(TokenBox<RegisterAnnotation>)
    case referenceAnnotation(TokenBox<ReferenceAnnotation>)
    case parameterAnnotation(TokenBox<ParameterAnnotation>)
    case configurationAnnotation(TokenBox<ConfigurationAnnotation>)
}

// MARK: - Sequence

struct ExprSequence: Sequence, IteratorProtocol {

    private var stack: [(exprs: [Expr], embeddingTypes: [ConcreteType], file: String?)]

    init(exprs: [Expr]) {
        self.stack = [(exprs, [], nil)]
    }

    mutating func next() -> (expr: Expr, embeddingTypes: [ConcreteType], file: String?)? {
        guard let (exprs, embeddingTypes, file) = stack.popLast() else {
            return nil
        }

        guard let expr = exprs.first else {
            return next()
        }

        var mutableExprs = exprs
        mutableExprs.removeFirst()
        stack.append((mutableExprs, embeddingTypes, file))

        switch expr {
        case .file(let exprs, let file, _):
            stack.append((exprs, embeddingTypes, file))
            
        case .typeDeclaration(let token, let exprs):
            stack.append((exprs, embeddingTypes + [token.value.type], file))

        case .referenceAnnotation,
             .registerAnnotation,
             .parameterAnnotation,
             .configurationAnnotation:
            break
        }

        return (expr, embeddingTypes, file)
    }
}

// MARK: - Description

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .file(let types, let name, _):
            return """
            File[\(name)]
            \(types.map { "|- \($0.description)" }.joined(separator: "\n"))
            """
        case .registerAnnotation(let token):
            return "Register - \(token.description)"
        case .typeDeclaration(let type, let children):
            return """
            \(type.description)
            \(children.map { "|-- \($0.description)" }.joined(separator: "\n"))
            """
        case .referenceAnnotation(let token):
            return "Reference - \(token.description)"
        case .parameterAnnotation(let token):
            return "Parameter - \(token.description)"
        case .configurationAnnotation(let token):
            return "Configuration - \(token.description)"
        }
    }
}

// MARK: - Convenience

extension Expr {
    
    func toRegisterAnnotation() -> TokenBox<RegisterAnnotation>? {
        switch self {
        case .registerAnnotation(let token):
            return token
        default:
            return nil
        }
    }
}
