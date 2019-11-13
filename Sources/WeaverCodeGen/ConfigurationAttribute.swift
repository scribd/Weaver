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
    case customBuilder = "builder"
    case scope
    case doesSupportObjc = "objc"
    case allowsCycles
    case onFatalError
}

enum ConfigurationAttribute: Equatable, Hashable {
    case isIsolated(value: Bool)
    case customBuilder(value: String)
    case scope(value: Scope)
    case doesSupportObjc(value: Bool)
    case allowsCycles(value: Bool)
    case onFatalError(value: String)
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
        case .customBuilder(let value):
            return "Config Attr - builder = \(value)"
        case .scope(let value):
            return "Config Attr - scope = \(value)"
        case .doesSupportObjc(let value):
            return "Config Attr - objc = \(value)"
        case .allowsCycles(let value):
            return "Config Attr - allowsCycles = \(value)"
        case .onFatalError(let value):
            return "Config Attr - fatalErrorFunction = \(value)"
        }
    }
    
    var name: ConfigurationAttributeName {
        switch self {
        case .isIsolated:
            return .isIsolated
        case .customBuilder:
            return .customBuilder
        case .scope:
            return .scope
        case .doesSupportObjc:
            return .doesSupportObjc
        case .allowsCycles:
            return .allowsCycles
        case .onFatalError:
            return .onFatalError
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
             (.allowsCycles, .`self`),
             (.onFatalError, .`self`),
             (.customBuilder, .dependency),
             (.scope, .dependency),
             (.doesSupportObjc, .dependency):
            return true
            
        case (.isIsolated, _),
             (.customBuilder, _),
             (.onFatalError, _),
             (.scope, _),
             (.doesSupportObjc, _),
             (.allowsCycles, _):
            return false
        }
    }
}

// MARK: - Parser Validation

extension ConfigurationAnnotation {
    
    static func validate(configurationAttribute: ConfigurationAttribute, with dependencyKind: ConfigurationAttributeDependencyKind) -> Bool {
        switch (configurationAttribute, dependencyKind) {
        case (.scope, .registration),
             (.customBuilder, _),
             (.doesSupportObjc, _),
             (.onFatalError, _):
            return true
        case (.isIsolated, _),
             (.scope, _),
             (.allowsCycles, _):
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
        case .customBuilder?:
            self = .customBuilder(value: valueString)
        case .scope?:
            self = .scope(value: try ConfigurationAttribute.scopeValue(from: valueString))
        case .doesSupportObjc?:
            self = .doesSupportObjc(value: try ConfigurationAttribute.boolValue(from: valueString))
        case .allowsCycles?:
            self = .allowsCycles(value: try ConfigurationAttribute.boolValue(from: valueString))
        case .onFatalError?:
            self = .onFatalError(value: valueString)
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
        case .isIsolated(let value),
             .doesSupportObjc(let value),
             .allowsCycles(let value):
            return value

        case .scope,
             .customBuilder,
             .onFatalError:
            return nil
        }
    }
    
    var scopeValue: Scope? {
        switch self {
        case .scope(let value):
            return value
            
        case .customBuilder,
             .isIsolated,
             .doesSupportObjc,
             .allowsCycles,
             .onFatalError:
            return nil
        }
    }
    
    var stringValue: String? {
        switch self {
        case .customBuilder(let value),
             .onFatalError(let value):
            return value
            
        case .scope,
             .isIsolated,
             .doesSupportObjc,
             .allowsCycles:
            return nil
        }
    }
}
