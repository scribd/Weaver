//
//  Parser.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

public final class Parser {
    
    private let tokens: [AnyTokenBox]

    private var index = 0
    
    public init(_ tokens: [AnyTokenBox]) {
        self.tokens = tokens
    }
    
    public func parse() throws -> Expr {
        return try parseFile()
    }
}

// MARK: - Error

extension Parser {
    
    public enum Error: Swift.Error {
        case unexpectedToken
        case unexpectedEOF
        
        case unknownDependency
        case missingDependency
        case depedencyDoubleDeclaration
    }
}

// MARK: - Utils

private extension Parser {
    
    var currentToken: AnyTokenBox? {
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
            case is TokenBox<EndOfAnyDeclaration>:
                consumeToken()
            case is TokenBox<AnyDeclaration>:
                consumeToken()
            default:
                return
            }
        }
    }
    
    func parseParentResolverAnnotation() throws -> TokenBox<ParentResolverAnnotation> {
        switch currentToken {
        case let token as TokenBox<ParentResolverAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }

    func parseRegisterAnnotation() throws -> TokenBox<RegisterAnnotation> {
        switch currentToken {
        case let token as TokenBox<RegisterAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }
    
    func parseScopeAnnotation() throws -> TokenBox<ScopeAnnotation> {
        switch currentToken {
        case let token as TokenBox<ScopeAnnotation>:
            consumeToken()
            return token
        case nil:
            throw Error.unexpectedEOF
        default:
            throw Error.unexpectedToken
        }
    }
    
    func parseInjectableType() throws -> TokenBox<InjectableType> {
        switch currentToken {
        case let token as TokenBox<InjectableType>:
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
        let type = try parseInjectableType()
        
        var children = [Expr]()
        var dependencyNames = Set<String>()
        
        while true {
            parseAnyDeclarations()

            switch currentToken {
            case is TokenBox<RegisterAnnotation>:
                let annotation = try parseRegisterAnnotation()
                guard !dependencyNames.contains(annotation.value.name) else {
                    throw Error.depedencyDoubleDeclaration
                }
                dependencyNames.insert(annotation.value.name)
                children.append(.registerAnnotation(annotation))
            
            case is TokenBox<ScopeAnnotation>:
                let annotation = try parseScopeAnnotation()
                guard dependencyNames.contains(annotation.value.name) else {
                    throw Error.unknownDependency
                }
                children.append(.scopeAnnotation(annotation))

            case is TokenBox<ParentResolverAnnotation>:
                children.append(try parseInjectedTypeDeclaration())
            
            case is TokenBox<InjectableType>:
                children.append(try parseInjectedTypeDeclaration())
            
            case is TokenBox<EndOfInjectableType>:
                consumeToken()
                guard !dependencyNames.isEmpty else {
                    throw Error.missingDependency
                }
                return .typeDeclaration(type, parentResolver: parentResolver, children: children)

            case nil:
                throw Error.unexpectedEOF
            
            default:
                throw Error.unexpectedToken
            }
        }
    }
    
    func parseFile() throws -> Expr {
        
        var types = [Expr]()
        
        while true {
            parseAnyDeclarations()

            switch currentToken {
            case is TokenBox<ParentResolverAnnotation>:
                types.append(try parseInjectedTypeDeclaration())
                
            case is TokenBox<InjectableType>:
                consumeToken()
                
            case is TokenBox<EndOfInjectableType>:
                consumeToken()

            case nil:
                return .file(types: types)
                
            default:
                throw Error.unexpectedToken
            }
        }
    }
}
