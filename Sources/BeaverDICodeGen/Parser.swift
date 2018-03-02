//
//  Parser.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

final class Parser {
    
    private let tokens: [AnyToken]

    private var index = 0
    
    init(_ tokens: [AnyToken]) {
        self.tokens = tokens
    }
    
    func parse() throws -> Expr {
        parseAnyDeclarations()
        return try parseInjectedTypeDeclaration()
    }
}

// MARK: - Error

extension Parser {
    
    enum Error: Swift.Error {
        case unexpectedToken
        case unexpectedEOF
        
        case dependencyMismatch
    }
}

// MARK: - Utils

private extension Parser {
    
    var currentToken: AnyToken? {
        return index < tokens.count ? tokens[index] : nil
    }
    
    func consumeToken(n: Int = 1) {
        index += n
    }
}

// MARK: - Parsing

private extension Parser {
    
    func parseAnyDeclarations() {
        while true {
            switch currentToken {
            case is Token<EndOfAnyDeclaration>:
                consumeToken()
            case is Token<AnyDeclaration>:
                consumeToken()
            default:
                return
            }
        }
    }
    
    func parseParentResolverAnnotation() throws -> Token<ParentResolverAnnotation> {
        switch currentToken {
        case let token as Token<ParentResolverAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }

    func parseRegisterAnnotation() throws -> Token<RegisterAnnotation> {
        switch currentToken {
        case let token as Token<RegisterAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }
    
    func parseScopeAnnotation() throws -> Token<ScopeAnnotation> {
        switch currentToken {
        case let token as Token<ScopeAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }
    
    @discardableResult
    func parseTypeDeclaration() throws -> Token<InjectableType> {
        switch currentToken {
        case let token as Token<InjectableType>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }
    
    func parseInjectedTypeDeclaration() throws -> Expr {
        let parentResolver = try parseParentResolverAnnotation()
        
        try parseTypeDeclaration()
        
        var children = [Expr]()
        while true {
            parseAnyDeclarations()

            switch currentToken {
            case is Token<RegisterAnnotation>:
                children.append(.registerAnnotation(try parseRegisterAnnotation()))
            
            case is Token<ScopeAnnotation>:
                children.append(.scopeAnnotation(try parseScopeAnnotation()))

            case is Token<ParentResolverAnnotation>:
                children.append(try parseInjectedTypeDeclaration())
            
            case is Token<InjectableType>:
                children.append(try parseInjectedTypeDeclaration())
            
            case is Token<EndOfInjectableType>:
                consumeToken()
                return .typeDeclaration(parentResolver: parentResolver, children: children)

            case nil:
                throw Error.unexpectedEOF
            
            default:
                throw Error.unexpectedToken
            }
        }
    }
}
