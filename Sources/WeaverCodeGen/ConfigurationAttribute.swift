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
}

enum ConfigurationAttribute: AutoEquatable, AutoHashable {
    case isIsolated(value: Bool)
    case customRef(value: Bool)
}

// MARK: - Targets

enum ConfigurationAttributeTarget: AutoEquatable, AutoHashable {
    case `self`
    case dependency(name: String)
}

// MARK: - Description

extension ConfigurationAttribute: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .isIsolated(let value):
            return "Config Attr - self.isIsolated = \(value)"
        case .customRef(let value):
            return "Config Attr - dependency.customRef = \(value)"
        }
    }
    
    var name: ConfigurationAttributeName {
        switch self {
        case .isIsolated:
            return .isIsolated
        case .customRef:
            return .customRef
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
             (.customRef, .dependency):
            return true
            
        case (.isIsolated, _),
             (.customRef, _):
            return false
        }
    }
}

// MARK: - Builders

extension ConfigurationAttribute {
    
    init(name: String, valueString: String) throws {

        guard let value = Bool(valueString) else {
            throw TokenError.invalidConfigurationAttributeValue(value: valueString, expected: "true|false")
        }

        switch name {
        case ConfigurationAttributeName.isIsolated.rawValue:
            self = .isIsolated(value: value)
            
        case ConfigurationAttributeName.customRef.rawValue:
            self = .customRef(value: value)
            
        default:
            throw TokenError.unknownConfigurationAttribute(name: name)
        }
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

    var boolValue: Bool {
        switch self {
        case .customRef(let value),
             .isIsolated(let value):
            return value
        }
    }
}
