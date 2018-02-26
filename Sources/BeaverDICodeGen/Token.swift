//
//  Token.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

enum TokenType {
    
    enum ScopeType: String {
        case transient = "transient"
        case graph = "graph"
        case weak = "weak"
        case container = "container"
        case parent = "parent"
    }

    enum AnnotationType {
        case parentResolver(type: String)
        case register(name: String, type: String)
        case resolve(String)
        case scope(name: String, scope: ScopeType)
    }
    
    case injectableType
    case endOfInjectableType
    case annotation(AnnotationType)
    case anyDeclaration
    case endOfAnyDeclaration
}

struct Token {
    let type: TokenType
    let offset: Int
    let length: Int
    var line: Int
}

// MARK: - Annotations

extension TokenType.AnnotationType {
    
    enum Error: Swift.Error {
        case invalidAnnotation(String)
        case invalidScope(String)
    }
    
    init?(stringValue: String) throws {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = stringValue.trimmingCharacters(in: chars)
        
        let bodyRegex = try NSRegularExpression(pattern: "^beaverdi\\s*:\\s*(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }
        
        if let value = try (
            TokenType.AnnotationType.makeParentResolverAnnotation(from: body) ??
            TokenType.AnnotationType.makeRegisterAnnotation(from: body) ??
            TokenType.AnnotationType.makeScopeAnnotation(from: body)
        ) {
            self = value
            return
        }
        
        throw Error.invalidAnnotation(annotation)
    }
}

// MARK: - Builders

private extension TokenType.AnnotationType {
    
    static func makeParentResolverAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^parent\\s*=\\s*(\\w+)").matches(in: string) else {
            return nil
        }
        return .parentResolver(type: matches[0])
    }
    
    static func makeRegisterAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\s*->\\s*(\\w+\\??)").matches(in: string) else {
            return nil
        }
        return .register(name: matches[0], type: matches[1])
    }
    
    static func makeScopeAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.scope\\s*=\\s*\\.(\\w+)").matches(in: string) else {
            return nil
        }

        guard let scope = TokenType.ScopeType(rawValue: matches[1]) else {
            throw Error.invalidScope(matches[1])
        }
        
        return .scope(name: matches[0], scope: scope)
    }
}

// MARK: Regex Util

private extension NSRegularExpression {
    
    func matches(in string: String) -> [String]? {
        let result = self
            .matches(in: string, range: NSMakeRange(0, string.utf16.count))
            .flatMap { match in (1..<match.numberOfRanges).map { match.range(at: $0) } }
            .flatMap { Range($0, in: string) }
            .map { String(string[$0]) }
        
        if result.isEmpty {
            return nil
        }
        return result
    }
}

// MARK: - Equatable

extension Token: Equatable {
    static func ==(lhs: Token, rhs: Token) -> Bool {
        return lhs.length == rhs.length &&
            lhs.line == rhs.line &&
            lhs.offset == rhs.offset &&
            lhs.type == rhs.type
    }
}

extension TokenType: Equatable {
    static func ==(lhs: TokenType, rhs: TokenType) -> Bool {
        switch (lhs, rhs) {
        case (.injectableType, .injectableType),
             (.endOfInjectableType, .endOfInjectableType),
             (.anyDeclaration, .anyDeclaration),
             (.endOfAnyDeclaration, .endOfAnyDeclaration):
            return true
            
        case (.annotation(let leftAnnotation), .annotation(let rightAnnotation)):
            return leftAnnotation == rightAnnotation

        case (.injectableType, _),
             (.endOfInjectableType, _),
             (.anyDeclaration, _),
             (.annotation, _),
             (.endOfAnyDeclaration, _):
            return false
        }
    }
}

extension TokenType.AnnotationType: Equatable {
    static func ==(lhs: TokenType.AnnotationType, rhs: TokenType.AnnotationType) -> Bool {
        switch (lhs, rhs) {
        case (.parentResolver(let leftName), .parentResolver(let rightName)):
            return leftName == rightName

        case (.register(let leftName, let leftType), .register(let rightName, let rightType)):
            return leftName == rightName && leftType == rightType
        
        case (.resolve(let leftName), .resolve(let rightName)):
            return leftName == rightName
        
        case (.scope(let leftName, let leftScope), .scope(let rightName, let rightScope)):
            return leftName == rightName && leftScope == rightScope
        
        case (.parentResolver, _),
             (.register, _),
             (.resolve, _),
             (.scope, _):
            return false
        }
    }
}
