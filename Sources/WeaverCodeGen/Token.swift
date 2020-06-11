//
//  Token.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

// MARK: - Token

public protocol AnyTokenBox: Codable, CustomStringConvertible {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

public struct TokenBox<T>: AnyTokenBox, Hashable where T: Token, T: Hashable {
    let value: T
    public let offset: Int
    public let length: Int
    public var line: Int
    
    public var description: String {
        return "\(value) - \(offset)[\(length)] - at line: \(line)"
    }
}

public protocol Token: CustomStringConvertible, Codable {
    static func create(fromComment annotation: String) throws -> Self?
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
    let abstractType: AbstractType
    let closureParameters: [TupleComponent]
    
    public static func create(fromComment annotation: String) throws -> RegisterAnnotation? {
        guard let matches = NSRegularExpression.register.matches(in: annotation) else {
            return nil
        }
        
        let valueComponents = matches[1]
            .replacingOccurrences(of: "<-", with: "|")
            .lazy
            .split(separator: "|")
            .map { String($0) }

        guard valueComponents.isEmpty == false && valueComponents.count <= 2 else {
            return nil
        }

        let type = try ConcreteType(value: CompositeType(valueComponents[0]))

        let abstractType: AbstractType
        if valueComponents.count > 1 {
            abstractType = try AbstractType(value: CompositeType(valueComponents[1]))
        } else {
            abstractType = AbstractType()
        }
        
        return RegisterAnnotation(style: .comment,
                                  name: matches[0],
                                  type: type,
                                  abstractType: abstractType,
                                  closureParameters: [])
    }
    
    public var description: String {
        var s = "\(name) = \(type.description)"
        if abstractType.isEmpty == false {
            s += " <- \(abstractType.description)"
        }
        return s
    }
}

public struct ReferenceAnnotation: Token, Hashable {
    
    let style: AnnotationStyle
    let name: String
    let type: AbstractType
    let closureParameters: [TupleComponent]
    
    public static func create(fromComment annotation: String) throws -> ReferenceAnnotation? {
        guard let matches = NSRegularExpression.reference.matches(in: annotation) else {
            return nil
        }
        
        let type = try AbstractType(value: CompositeType(matches[1]))
        
        return ReferenceAnnotation(style: .comment,
                                   name: matches[0],
                                   type: type,
                                   closureParameters: [])
    }
    
    public var description: String {
        return "\(name) <- \(type.description)"
    }
}

public struct ParameterAnnotation: Token, Hashable {
    
    public let style: AnnotationStyle
    public let name: String
    public let type: ConcreteType
    
    public static func create(fromComment annotation: String) throws -> ParameterAnnotation? {
        guard let matches = NSRegularExpression.parameter.matches(in: annotation) else {
            return nil
        }

        let type = try ConcreteType(value: CompositeType(matches[1]))
        
        return ParameterAnnotation(style: .comment,
                                   name: matches[0],
                                   type: type)
    }
    
    public var description: String {
        return "\(name) <= \(type.description)"
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
    
    public static func create(fromComment annotation: String) throws -> ConfigurationAnnotation? {
        guard let matches = NSRegularExpression.configuration.matches(in: annotation) else {
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
        return "\(target.description).\(attribute.description)"
    }
}

public struct ImportDeclaration: Token, Hashable {
    
    let moduleName: String
    
    public static func create(fromComment annotation: String) throws -> ImportDeclaration? {
        guard let matches = NSRegularExpression.import.matches(in: annotation) else {
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
        return "\(accessLevel.rawValue) \(type.description) {"
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
        
        if let token = try ConfigurationAnnotation.create(fromComment: body) {
            return makeTokenBox(token)
        }
        if let token = try RegisterAnnotation.create(fromComment: body) {
            return makeTokenBox(token)
        }
        if let token = try ReferenceAnnotation.create(fromComment: body) {
            return makeTokenBox(token)
        }
        if let token = try ParameterAnnotation.create(fromComment: body) {
            return makeTokenBox(token)
        }
        if let token = try ImportDeclaration.create(fromComment: body) {
            return makeTokenBox(token)
        }
        throw TokenError.invalidAnnotation(annotation)
    }
}

// MARK: - Default implementations

extension Token {
    public static func create(fromComment annotation: String) throws -> Self? {
        return nil
    }
}

