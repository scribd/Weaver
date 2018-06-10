//
//  Token.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework
import WeaverDI

// MARK: - Token

public protocol AnyTokenBox {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

public struct TokenBox<T: Token>: AnyTokenBox, Equatable, CustomStringConvertible {
    let value: T
    public let offset: Int
    public let length: Int
    public var line: Int
    
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

public protocol Token: AutoEquatable, CustomStringConvertible {
    static func create(_ string: String) throws -> Self?
}

// MARK: - Token Types

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
    
    public var description: String {
        var s = "\(name) = \(typeName)"
        if let protocolName = protocolName {
            s += " <- \(protocolName)"
        }
        return s
    }
}

public struct ScopeAnnotation: Token {

    let name: String
    let scope: Scope
    
    public static func create(_ string: String) throws -> ScopeAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.scope\\s*=\\s*\\.(\\w+)\\s*$").matches(in: string) else {
            return nil
        }
        
        guard let scope = Scope(matches[1]) else {
            throw TokenError.invalidScope(matches[1])
        }
        
        return ScopeAnnotation(name: matches[0], scope: scope)
    }
    
    public var description: String {
        return "\(name).scope = \(scope)"
    }
}

public struct ReferenceAnnotation: Token {
    
    let name: String
    let typeName: String
    
    public static func create(_ string: String) throws -> ReferenceAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\s*<-\\s*(\\w+\\??)\\s*$").matches(in: string) else {
            return nil
        }
        return ReferenceAnnotation(name: matches[0], typeName: matches[1])
    }
    
    public var description: String {
        return "\(name) <- \(typeName)"
    }
}

public struct ParameterAnnotation: Token {
    
    let name: String
    let typeName: String
    
    public static func create(_ string: String) throws -> ParameterAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\s*<=\\s*(\\w+\\??)\\s*$").matches(in: string) else {
            return nil
        }
        return ParameterAnnotation(name: matches[0], typeName: matches[1])
    }
    
    public var description: String {
        return "\(name) <= \(typeName)"
    }
}

public struct ConfigurationAnnotation: Token, AutoHashable {
    
    let attribute: ConfigurationAttribute
    
    let target: ConfigurationAttributeTarget
    
    public static func create(_ string: String) throws -> ConfigurationAnnotation? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.(\\w+)\\s*=\\s*(\\w+\\??)\\s*$").matches(in: string) else {
            return nil
        }
        
        let target = ConfigurationAttributeTarget(matches[0])
        let attribute = try ConfigurationAttribute(name: matches[1], valueString: matches[2])
        
        guard validate(configurationAttribute: attribute, with: target) else {
            throw TokenError.invalidConfigurationAttributeTarget(name: attribute.name.rawValue, target: target)
        }
        
        return ConfigurationAnnotation(attribute: attribute, target: target)
    }
    
    public var description: String {
        return "\(target).\(attribute)"
    }
}

public struct InjectableType: Token {
    let name: String
    let accessLevel: AccessLevel
    let doesSupportObjc: Bool

    init(name: String,
         accessLevel: AccessLevel = .default,
         doesSupportObjc: Bool = false) {
        self.name = name
        self.accessLevel = accessLevel
        self.doesSupportObjc = doesSupportObjc
    }
    
    public var description: String {
        return "\(accessLevel.rawValue) \(name) {"
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

// MARK: - Annotation Builder

enum TokenBuilder {

    static func makeAnnotationToken(string: String,
                                    offset: Int,
                                    length: Int,
                                    line: Int) throws -> AnyTokenBox? {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = string.trimmingCharacters(in: chars)

        let bodyRegex = try NSRegularExpression(pattern: "^weaver\\s*:\\s*(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }

        func makeTokenBox<T: Token>(_ token: T) -> AnyTokenBox {
            return TokenBox(value: token, offset: offset, length: length, line: line)
        }
        
        if let token = try ConfigurationAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try RegisterAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ReferenceAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ScopeAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ParameterAnnotation.create(body) {
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
            .compactMap { Range($0, in: string) }
            .map { String(string[$0]) }
        
        if result.isEmpty {
            return nil
        }
        return result
    }
}
