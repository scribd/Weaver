//
//  Token.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

// MARK: - Token

public protocol AnyTokenBox: Codable {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

public struct TokenBox<T: Token & Hashable>: AnyTokenBox, Hashable, CustomStringConvertible {
    let value: T
    public let offset: Int
    public let length: Int
    public var line: Int
    
    public var description: String {
        return "\(value) - \(offset)[\(length)] - at line: \(line)"
    }
}

public protocol Token: CustomStringConvertible, Codable {
    static func create(_ string: String) throws -> Self?
}

public enum AnnotationStyle: String, Hashable {
    case comment
    case propertyWrapper
}

// MARK: - Token SwiftTypes

public struct RegisterAnnotation: Token, Hashable {

    let style: AnnotationStyle
    let name: String
    let type: ConcreteType
    let protocolTypes: Set<AbstractType>
    
    public static func create(_ string: String) throws -> RegisterAnnotation? {
        guard let matches = NSRegularExpression.register.matches(in: string) else {
            return nil
        }

        var protocolTypes = [AbstractType]()
        let arrowIndex = matches.firstIndex { $0.hasPrefix("<-") }
        if let arrowIndex = arrowIndex, arrowIndex + 1 < matches.count, let type = try AbstractType(matches[arrowIndex + 1]) {
            protocolTypes.append(type)
            
            for (index, match) in matches.enumerated() where match.hasPrefix("&") {
                if let type = try AbstractType(matches[index + 1]) {
                    protocolTypes.append(type)
                } else {
                    return nil
                }
            }
        }
        
        guard let type = try ConcreteType(matches[1]) else {
            return nil
        }
        
        return RegisterAnnotation(style: .comment,
                                  name: matches[0],
                                  type: type,
                                  protocolTypes: Set(protocolTypes))
    }
    
    public var description: String {
        var s = "\(name) = \(type)"
        if protocolTypes.isEmpty == false {
            s += " <- \(protocolTypes.lazy.map { $0.description }.sorted())"
        }
        return s
    }
}

public struct ReferenceAnnotation: Token, Hashable {
    
    public let style: AnnotationStyle
    public let name: String
    public let types: Set<AbstractType>
    
    public static func create(_ string: String) throws -> ReferenceAnnotation? {
        guard let matches = NSRegularExpression.reference.matches(in: string) else {
            return nil
        }
        guard let firstType = try AbstractType(matches[1]) else {
            return nil
        }
        var types = [firstType]
        for (index, match) in matches.enumerated() where match.hasPrefix("&") {
            if let type = try AbstractType(matches[index + 1]) {
                types.append(type)
            } else {
                return nil
            }
        }
        return ReferenceAnnotation(style: .comment, name: matches[0], types: Set(types))
    }
    
    public var description: String {
        return "\(name) <- \(types.lazy.map { $0.description }.sorted())"
    }
}

public struct ParameterAnnotation: Token, Hashable {
    
    public let style: AnnotationStyle
    public let name: String
    public let type: ConcreteType
    
    public static func create(_ string: String) throws -> ParameterAnnotation? {
        guard let matches = NSRegularExpression.parameter.matches(in: string) else {
            return nil
        }
        guard let type = try ConcreteType(matches[1]) else {
            return nil
        }
        return ParameterAnnotation(style: .comment, name: matches[0], type: type)
    }
    
    public var description: String {
        return "\(name) <= \(type)"
    }
}

public struct ConfigurationAnnotation: Token, Hashable {
    
    public let attribute: ConfigurationAttribute
    
    public let target: ConfigurationAttributeTarget
    
    struct UniqueIdentifier: Hashable, Equatable {
        let name: ConfigurationAttributeName
        let target: ConfigurationAttributeTarget
    }

    var uniqueIdentifier: UniqueIdentifier {
        return UniqueIdentifier(name: attribute.name, target: target)
    }
    
    public static func create(_ string: String) throws -> ConfigurationAnnotation? {
        guard let matches = NSRegularExpression.configuration.matches(in: string) else {
            return nil
        }
        
        let target = ConfigurationAttributeTarget(matches[0])
        let attribute = try ConfigurationAttribute(name: matches[1], valueString: matches[2])
        
        guard validate(configurationAttribute: attribute, with: target) else {
            throw TokenError.invalidConfigurationAttributeTarget(name: attribute.name.rawValue, target: target)
        }
        
        return ConfigurationAnnotation(attribute: attribute, target: target)
    }
    
    public static func create(attribute: ConfigurationAttribute, target: ConfigurationAttributeTarget) throws -> ConfigurationAnnotation {
        guard validate(configurationAttribute: attribute, with: target) else {
            throw TokenError.invalidConfigurationAttributeTarget(name: attribute.name.rawValue, target: target)
        }
        
        return ConfigurationAnnotation(attribute: attribute, target: target)
    }
    
    public var description: String {
        return "\(target).\(attribute)"
    }
}

public struct ImportDeclaration: Token, Hashable {
    
    let moduleName: String
    
    public static func create(_ string: String) throws -> ImportDeclaration? {
        guard let matches = NSRegularExpression.import.matches(in: string) else {
            return nil
        }
        
        return ImportDeclaration(moduleName: matches[0])
    }
    
    public var description: String {
        return "import \(moduleName)"
    }
}

public struct InjectableType: Token, Hashable {

    let type: ConcreteType
    let accessLevel: AccessLevel

    init(type: ConcreteType,
         accessLevel: AccessLevel = .default) {
        self.type = type
        self.accessLevel = accessLevel
    }
    
    public var description: String {
        return "\(accessLevel.rawValue) \(type) {"
    }
}

public struct EndOfInjectableType: Token, Hashable {
    
    public let description: String
    
    init() {
        description = "_ }"
    }
}

public struct AnyDeclaration: Token, Hashable {
    
    public let description: String
    
    init() {
        description = "{"
    }
}

public struct EndOfAnyDeclaration: Token, Hashable {

    public let description: String
    
    init() {
        description = "}"
    }
}

// MARK: - Annotation Builder

public enum TokenBuilder {
    
    public static let annotationRegexString = "weaver[[:space:]]*:"
    static let annotationRegex = try! NSRegularExpression(pattern: "^\(TokenBuilder.annotationRegexString)[[:space:]]*(.*)")

    static func makeAnnotationToken(string: String,
                                    offset: Int,
                                    length: Int,
                                    line: Int) throws -> AnyTokenBox? {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = string.trimmingCharacters(in: chars)

        guard let body = TokenBuilder.annotationRegex.matches(in: annotation)?.first else {
            return nil
        }

        func makeTokenBox<T: Token & Equatable & Hashable>(_ token: T) -> AnyTokenBox {
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
        if let token = try ParameterAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ImportDeclaration.create(body) {
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
}

