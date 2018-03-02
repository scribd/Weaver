//
//  Token.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

// MARK: - Token

protocol AnyToken {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

struct Token<T: TokenType>: AnyToken {
    let type: T
    let offset: Int
    let length: Int
    var line: Int
}

protocol TokenType: Equatable, CustomStringConvertible {
    static func create(_ string: String) throws -> Self?
}

enum TokenError: Swift.Error {
    case invalidAnnotation(String)
    case invalidScope(String)
}

// MARK: - Token Types

struct ParentResolverAnnotation: TokenType {
    let type: String
    
    static func create(_ string: String) throws -> ParentResolverAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^parent\\s*=\\s*(\\w+)").matches(in: string) else {
            return nil
        }
        return ParentResolverAnnotation(type: matches[0])
    }
    
    static func ==(lhs: ParentResolverAnnotation, rhs: ParentResolverAnnotation) -> Bool {
        return lhs.type == rhs.type
    }
    
    var description: String {
        return "parent = \(type)"
    }
}

struct RegisterAnnotation: TokenType {
    let name: String
    let type: String
    
    static func create(_ string: String) throws -> RegisterAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\s*->\\s*(\\w+\\??)").matches(in: string) else {
            return nil
        }
        return RegisterAnnotation(name: matches[0], type: matches[1])
    }
    
    static func ==(lhs: RegisterAnnotation, rhs: RegisterAnnotation) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.type == rhs.type else { return false }
        return true
    }
    
    var description: String {
        return "\(name) -> \(type)"
    }
}

struct ScopeAnnotation: TokenType {
    
    enum ScopeType: String {
        case transient = "transient"
        case graph = "graph"
        case weak = "weak"
        case container = "container"
        case parent = "parent"
    }
    
    let name: String
    let scope: ScopeType
    
    static func create(_ string: String) throws -> ScopeAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.scope\\s*=\\s*\\.(\\w+)").matches(in: string) else {
            return nil
        }
        
        guard let scope = ScopeType(rawValue: matches[1]) else {
            throw TokenError.invalidScope(matches[1])
        }
        
        return ScopeAnnotation(name: matches[0], scope: scope)
    }
    
    static func ==(lhs: ScopeAnnotation, rhs: ScopeAnnotation) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.scope == rhs.scope else { return false }
        return true
    }
    
    var description: String {
        return "\(name).scope = \(scope)"
    }
}

struct InjectableType: TokenType {
    let description = "{"
}

struct EndOfInjectableType: TokenType {
    let description = "}"
}

struct AnyDeclaration: TokenType {
    let description = "{"
}

struct EndOfAnyDeclaration: TokenType {
    let description = "}"
}

extension Token: Equatable, CustomStringConvertible {
    static func ==(lhs: Token<T>, rhs: Token<T>) -> Bool {
        guard lhs.type == rhs.type else { return false }
        guard lhs.offset == rhs.offset else { return false }
        guard lhs.length == rhs.length else { return false }
        guard lhs.line == rhs.line else { return false }
        return true
    }
    
    var description: String {
        return "\(type) - \(offset)[\(length)] - at line: \(line)"
    }
}

// MARK: - Annotation Builder

enum TokenBuilder {

    static func makeAnnotationToken(string: String,
                                    offset: Int,
                                    length: Int,
                                    line: Int) throws -> AnyToken? {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = string.trimmingCharacters(in: chars)

        let bodyRegex = try NSRegularExpression(pattern: "^beaverdi\\s*:\\s*(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }

        func makeToken<T: TokenType>(_ type: T) -> AnyToken {
            return Token(type: type, offset: offset, length: length, line: line)
        }
        
        if let type = try ParentResolverAnnotation.create(body) {
            return makeToken(type)
        }
        if let type = try RegisterAnnotation.create(body) {
            return makeToken(type)
        }
        if let type = try ScopeAnnotation.create(body) {
            return makeToken(type)
        }
        throw TokenError.invalidAnnotation(annotation)
    }
}

// MARK: - Default implementations

extension TokenType {
    static func create(_ string: String) throws -> Self? {
        return nil
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return true
    }
}

// MARK: - Regex Util

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


