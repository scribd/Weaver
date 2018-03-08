//
//  Token.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

// MARK: - Token

public protocol AnyTokenBox {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

public struct TokenBox<T: Token>: AnyTokenBox {
    let value: T
    public let offset: Int
    public let length: Int
    public var line: Int
}

public protocol Token: Equatable, CustomStringConvertible {
    static func create(_ string: String) throws -> Self?
}

// MARK: - Token Types

public struct ParentResolverAnnotation: Token {
    let typeName: String
    
    public static func create(_ string: String) throws -> ParentResolverAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^parent\\s*=\\s*(\\w+)\\s*$").matches(in: string) else {
            return nil
        }
        return ParentResolverAnnotation(typeName: matches[0])
    }
    
    public static func ==(lhs: ParentResolverAnnotation, rhs: ParentResolverAnnotation) -> Bool {
        return lhs.typeName == rhs.typeName
    }
    
    public var description: String {
        return "parent = \(typeName)"
    }
}

public struct RegisterAnnotation: Token {
    let name: String
    let typeName: String
    let protocolName: String?
    
    public static func create(_ string: String) throws -> RegisterAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\s*=\\s*(\\w+\\??)\\s*(<-\\s*(\\w+\\??)\\s*)?$").matches(in: string) else {
            return nil
        }
        return RegisterAnnotation(name: matches[0], typeName: matches[1], protocolName: matches.count >= 4 ? matches[3] : nil)
    }
    
    public static func ==(lhs: RegisterAnnotation, rhs: RegisterAnnotation) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.typeName == rhs.typeName else { return false }
        guard lhs.protocolName == rhs.protocolName else { return false }
        return true
    }
    
    public var description: String {
        var s = "\(name) = \(typeName)"
        if let protocolName = protocolName {
            s += " <- \(protocolName)"
        }
        return s
    }
}

public struct ScopeAnnotation: Token {
    
    enum ScopeType: String {
        case transient = "transient"
        case graph = "graph"
        case weak = "weak"
        case container = "container"
        case parent = "parent"
    }
    
    let name: String
    let scope: ScopeType
    
    public static func create(_ string: String) throws -> ScopeAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.scope\\s*=\\s*\\.(\\w+)\\s*$").matches(in: string) else {
            return nil
        }
        
        guard let scope = ScopeType(rawValue: matches[1]) else {
            throw TokenError.invalidScope(matches[1])
        }
        
        return ScopeAnnotation(name: matches[0], scope: scope)
    }
    
    public static func ==(lhs: ScopeAnnotation, rhs: ScopeAnnotation) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.scope == rhs.scope else { return false }
        return true
    }
    
    public var description: String {
        return "\(name).scope = \(scope)"
    }
}

public struct InjectableType: Token {
    let name: String

    public static func ==(lhs: InjectableType, rhs: InjectableType) -> Bool {
        guard lhs.name == rhs.name else { return false }
        return true
    }

    public var description: String {
        return "\(name) {"
    }
}

public struct EndOfInjectableType: Token {
    public let description = "}"
}

public struct AnyDeclaration: Token {
    public let description = "{"
}

public struct EndOfAnyDeclaration: Token {
    public let description = "}"
}

extension TokenBox: Equatable, CustomStringConvertible {
    public static func ==(lhs: TokenBox<T>, rhs: TokenBox<T>) -> Bool {
        guard lhs.value == rhs.value else { return false }
        guard lhs.offset == rhs.offset else { return false }
        guard lhs.length == rhs.length else { return false }
        guard lhs.line == rhs.line else { return false }
        return true
    }
    
    public var description: String {
        return "\(value) - \(offset)[\(length)] - at line: \(line)"
    }
}

// MARK: - Annotation Builder

enum TokenBuilder {

    static func makeAnnotationToken(string: String,
                                    offset: Int,
                                    length: Int,
                                    line: Int) throws -> AnyTokenBox? {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = string.trimmingCharacters(in: chars)

        let bodyRegex = try NSRegularExpression(pattern: "^beaverdi\\s*:\\s*(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }

        func makeTokenBox<T: Token>(_ token: T) -> AnyTokenBox {
            return TokenBox(value: token, offset: offset, length: length, line: line)
        }
        
        if let token = try ParentResolverAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try RegisterAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ScopeAnnotation.create(body) {
            return makeTokenBox(token)
        }
        throw TokenError.invalidAnnotation(annotation)
    }
}

// MARK: - Default implementations

extension Token {
    public static func create(_ string: String) throws -> Self? {
        return nil
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
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


