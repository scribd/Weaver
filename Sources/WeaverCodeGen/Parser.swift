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
            throw ParserError.unexpectedEOF(FileLocation(file: fileName))
        case .some(let token):
            throw ParserError.unexpectedToken(FileLocation(line: token.line, file: fileName))
        }
    }

    func parseInjectedTypeDeclaration() throws -> Expr? {
        let type = try parseSimpleExpr(InjectableType.self)
        
        var children = [Expr]()
        var configurationAnnotations = [ConfigurationAttributeTarget: [ConfigurationAnnotation.UniqueIdentifier: TokenBox<ConfigurationAnnotation>]]()
        var registrationNames = Set<String>()
        var referenceNames = Set<String>()
        var parameterNames = Set<String>()
        
        let checkDoubleDeclaration = { (name: String, line: Int) throws in
            guard !registrationNames.contains(name) && !referenceNames.contains(name) && !parameterNames.contains(name) else {
                throw ParserError.dependencyDoubleDeclaration(name, FileLocation(line: line, file: self.fileName))
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
                            
            case is TokenBox<ConfigurationAnnotation>:
                let annotation = try parseSimpleExpr(ConfigurationAnnotation.self)
                var annotations = configurationAnnotations[annotation.value.target] ?? [:]
                guard annotations[annotation.value.uniqueIdentifier] == nil else {
                    throw ParserError.configurationAttributeDoubleAssignation(FileLocation(line: annotation.line, file: fileName),
                                                                              attribute: annotation.value.attribute)
                }
                annotations[annotation.value.uniqueIdentifier] = annotation
                configurationAnnotations[annotation.value.target] = annotations
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
                throw ParserError.unexpectedEOF(FileLocation(file: fileName))
            
            case .some(let token):
                throw ParserError.unexpectedToken(FileLocation(line: token.line, file: fileName))
            }
            
            for configurationAnnotation in configurationAnnotations.values.flatMap({ $0.values }) {
                try validate(configurationAnnotation,
                             referenceNames: referenceNames,
                             registrationNames: registrationNames,
                             parameterNames: parameterNames)
            }
            
            parseAnyDeclarations()
        }
    }
    
    func validate(_ configurationAnnotation: TokenBox<ConfigurationAnnotation>,
                   referenceNames: Set<String>,
                  registrationNames: Set<String>,
                  parameterNames: Set<String>) throws {
        
        switch configurationAnnotation.value.target {
        case .dependency(let name):
            let _dependencyKind: ConfigurationAttributeDependencyKind? = referenceNames.contains(name) ?
                .reference : registrationNames.contains(name) ?
                .registration : parameterNames.contains(name) ?
                .parameter : nil
            
            let fileLocation = FileLocation(line: configurationAnnotation.line, file: fileName)
            if let dependencyKind = _dependencyKind {
                let attribute = configurationAnnotation.value.attribute
                guard ConfigurationAnnotation.validate(configurationAttribute: attribute, with: dependencyKind) else {
                    throw ParserError.incompatibleConfigurationAttribute(fileLocation, attribute: attribute, dependencyName: name)
                }
            } else {
                throw ParserError.unknownDependency(name, fileLocation)
            }
            
        case .`self`:
            break
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
                throw ParserError.unexpectedToken(FileLocation(line: token.line, file: fileName))
            }
        }
    }
}
