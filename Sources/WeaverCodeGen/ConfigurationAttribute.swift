//
//  ConfigurationAttribute.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 5/13/18.
//

import Foundation

// MARK: - Attributes

enum ConfigurationAttributeName: String {
    case isIsolated
    case customRef
    case scope
}

enum ConfigurationAttribute: Equatable, Hashable {
    case isIsolated(value: Bool)
    case customRef(value: Bool)
    case scope(value: Scope)
}

// MARK: - Target

enum ConfigurationAttributeTarget: Equatable, Hashable {
    case `self`
    case dependency(name: String)
}

// MARK: - DependencyKind

enum ConfigurationAttributeDependencyKind {
    case reference
    case registration
}

// MARK: - Description

extension ConfigurationAttribute: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .isIsolated(let value):
            return "Config Attr - isIsolated = \(value)"
        case .customRef(let value):
            return "Config Attr - customRef = \(value)"
        case .scope(let value):
            return "Config Attr - scope = \(value)"
        }
    }
    
    var name: ConfigurationAttributeName {
        switch self {
        case .isIsolated:
            return .isIsolated
        case .customRef:
            return .customRef
        case .scope:
            return .scope
        }
    }
}

extension ConfigurationAttributeTarget: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .`self`:
            return "self"
        case .dependency(let name):
            return name
        }
    }
}

// MARK: - Lexer Validation

extension ConfigurationAnnotation {
    
    static func validate(configurationAttribute: ConfigurationAttribute, with target: ConfigurationAttributeTarget) -> Bool {
        switch (configurationAttribute, target) {
        case (.isIsolated, .`self`),
             (.customRef, .dependency),
             (.scope, .dependency):
            return true
            
        case (.isIsolated, _),
             (.customRef, _),
             (.scope, _):
            return false
        }
    }
}

// MARK: - Parser Validation

extension ConfigurationAnnotation {
    
    static func validate(configurationAttribute: ConfigurationAttribute, with dependencyKind: ConfigurationAttributeDependencyKind) -> Bool {
        switch (configurationAttribute, dependencyKind) {
        case (.scope, .registration),
             (.customRef, _):
            
            return true
        case (.isIsolated, _),
             (.scope, _):
            return false
        }
    }
}

// MARK: - Builders

extension ConfigurationAttribute {
    
    init(name: String, valueString: String) throws {
        switch ConfigurationAttributeName(rawValue: name) {
        case .isIsolated?:
            self = .isIsolated(value: try ConfigurationAttribute.boolValue(from: valueString))
            
        case .customRef?:
            self = .customRef(value: try ConfigurationAttribute.boolValue(from: valueString))
            
        case .scope?:
            self = .scope(value: try ConfigurationAttribute.scopeValue(from: valueString))
            
        case .none:
            throw TokenError.unknownConfigurationAttribute(name: name)
        }
    }
    
    private static func boolValue(from string: String) throws -> Bool {
        guard let value = Bool(string) else {
            throw TokenError.invalidConfigurationAttributeValue(value: string, expected: "true|false")
        }
        return value
    }
    
    private static func scopeValue(from string: String) throws -> Scope {
        guard string.first == ".", let value = Scope(rawValue: string.replacingOccurrences(of: ".", with: "")) else {
            let expected = Scope.allCases.map { $0.rawValue }.joined(separator: "|")
            throw TokenError.invalidConfigurationAttributeValue(value: string, expected: expected)
        }
        return value
    }
}

extension ConfigurationAttributeTarget {
    
    init(_ string: String) {
        switch string {
        case "self":
            self = .`self`
        case let name:
            self = .dependency(name: name)
        }
    }
}

// MARK: - Value

extension ConfigurationAttribute {

    var boolValue: Bool? {
        switch self {
        case .customRef(let value),
             .isIsolated(let value):
            return value

        case .scope:
            return nil
        }
    }
    
    var scopeValue: Scope? {
        switch self {
        case .scope(let value):
            return value
            
        case .customRef,
             .isIsolated:
            return nil
        }
    }
}
