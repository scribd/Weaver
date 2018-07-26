//
//  Parser.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/28/18.
//

import Foundation

public final class Parser {
    
    private let tokens: [AnyTokenBox]
    private let fileName: String

    private var index = 0
    
    public init(_ tokens: [AnyTokenBox], fileName: String) {
        self.tokens = tokens
        self.fileName = fileName
    }
    
    public func parse() throws -> Expr {
        return try parseFile()
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

// MARK: - Printable

private extension Parser {
    
    func fileLocation(line: Int? = nil) -> FileLocation {
        return FileLocation(line: line, file: fileName)
    }
    
    func printableDependency(line: Int?, name: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: fileLocation(line: line), name: name, type: nil)
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
    
    func parseSimpleExpr<TokenType: Token>(_: TokenType.Type) throws -> TokenBox<TokenType> {
        switch currentToken {
        case let token as TokenBox<TokenType>:
            consumeToken()
            return token
        case nil:
            throw ParserError.unexpectedEOF(fileLocation())
        case .some(let token):
            throw ParserError.unexpectedToken(fileLocation(line: token.line))
        }
    }

    func parseInjectedTypeDeclaration() throws -> Expr? {
        let type = try parseSimpleExpr(InjectableType.self)
        
        var children = [Expr]()
        var configurationAnnotations = [ConfigurationAttributeTarget: TokenBox<ConfigurationAnnotation>]()
        var registrationNames = Set<String>()
        var referenceNames = Set<String>()
        var parameterNames = Set<String>()
        
        let checkDoubleDeclaration = { (name: String, line: Int) throws in
            let dependency = self.printableDependency(line: line, name: name)
            guard !registrationNames.contains(name) && !referenceNames.contains(name) && !parameterNames.contains(name) else {
                throw ParserError.dependencyDoubleDeclaration(dependency)
            }
        }
        
        parseAnyDeclarations()
        guard currentToken != nil else {
            return nil
        }
        
        while true {
            switch currentToken {
            case is TokenBox<RegisterAnnotation>:
                let annotation = try parseSimpleExpr(RegisterAnnotation.self)
                let name = annotation.value.name
                try checkDoubleDeclaration(name, annotation.line)
                registrationNames.insert(name)
                children.append(.registerAnnotation(annotation))
            
            case is TokenBox<ReferenceAnnotation>:
                let annotation = try parseSimpleExpr(ReferenceAnnotation.self)
                let name = annotation.value.name
                try checkDoubleDeclaration(name, annotation.line)
                referenceNames.insert(name)
                children.append(.referenceAnnotation(annotation))
                
            case is TokenBox<ParameterAnnotation>:
                let annotation = try parseSimpleExpr(ParameterAnnotation.self)
                let name = annotation.value.name
                try checkDoubleDeclaration(name, annotation.line)
                parameterNames.insert(name)
                children.append(.parameterAnnotation(annotation))
                
            case is TokenBox<ScopeAnnotation>:
                let annotation = try parseSimpleExpr(ScopeAnnotation.self)
                guard registrationNames.contains(annotation.value.name) else {
                    let dependency = printableDependency(line: annotation.line,
                                                         name: annotation.value.name)
                    throw ParserError.unknownDependency(dependency)
                }
                children.append(.scopeAnnotation(annotation))
            
            case is TokenBox<ConfigurationAnnotation>:
                let annotation = try parseSimpleExpr(ConfigurationAnnotation.self)
                guard configurationAnnotations[annotation.value.target] == nil else {
                    throw ParserError.configurationAttributeDoubleAssignation(fileLocation(line: annotation.line),
                                                                              attribute: annotation.value.attribute)
                }
                configurationAnnotations[annotation.value.target] = annotation
                children.append(.configurationAnnotation(annotation))
                
            case is TokenBox<InjectableType>:
                if let typeDeclaration = try parseInjectedTypeDeclaration() {
                    children.append(typeDeclaration)
                }
                
            case is TokenBox<EndOfInjectableType>:
                consumeToken()
                if children.isEmpty {
                    return nil
                } else {
                    return .typeDeclaration(type, children: children)
                }

            case nil:
                throw ParserError.unexpectedEOF(fileLocation())
            
            case .some(let token):
                throw ParserError.unexpectedToken(fileLocation(line: token.line))
            }
            
            for configurationAnnotation in configurationAnnotations.values {
                switch configurationAnnotation.value.target {
                case .dependency(let name) where !referenceNames.contains(name) && !registrationNames.contains(name):
                    throw ParserError.unknownDependency(printableDependency(line: configurationAnnotation.line, name: name))
                    
                case .dependency,
                     .`self`:
                    break
                }
            }
            
            parseAnyDeclarations()
        }
    }
    
    func parseFile() throws -> Expr {
        
        var types = [Expr]()
        var imports = Set<String>()
        
        while true {
            parseAnyDeclarations()

            switch currentToken {
            case is TokenBox<InjectableType>:
                if let typeDeclaration = try parseInjectedTypeDeclaration() {
                    types.append(typeDeclaration)
                }
                
            case is TokenBox<ImportDeclaration>:
                let annotation = try parseSimpleExpr(ImportDeclaration.self)
                imports.insert(annotation.value.moduleName)

            case is TokenBox<EndOfInjectableType>:
                consumeToken()
                
            case nil:
                let sortedImports = imports.sorted { (lhs, rhs) -> Bool in
                    return lhs < rhs
                }
                return .file(types: types, name: fileName, imports: sortedImports)
                
            case .some(let token):
                throw ParserError.unexpectedToken(fileLocation(line: token.line))
            }
        }
    }
}


