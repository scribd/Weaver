//
//  Codable.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 12/5/19.
//

import Foundation

extension ConfigurationAttribute: Codable {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case value = "v"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        switch try container.decode(ConfigurationAttributeName.self, forKey: .name) {
        case .customBuilder:
            self = .customBuilder(value: try container.decode(String.self, forKey: .value))
        case .doesSupportObjc:
            self = .doesSupportObjc(value: try container.decode(Bool.self, forKey: .value))
        case .isIsolated:
            self = .isIsolated(value: try container.decode(Bool.self, forKey: .value))
        case .scope:
            self = .scope(value: try container.decode(Scope.self, forKey: .value))
        case .setter:
            self = .setter(value: try container.decode(Bool.self, forKey: .value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .customBuilder(let value):
            try container.encode(ConfigurationAttributeName.customBuilder, forKey: .name)
            try container.encode(value, forKey: .value)
        case .doesSupportObjc(let value):
            try container.encode(ConfigurationAttributeName.doesSupportObjc, forKey: .name)
            try container.encode(value, forKey: .value)
        case .isIsolated(let value):
            try container.encode(ConfigurationAttributeName.isIsolated, forKey: .name)
            try container.encode(value, forKey: .value)
        case .scope(let value):
            try container.encode(ConfigurationAttributeName.scope, forKey: .name)
            try container.encode(value, forKey: .value)
        case .setter(let value):
            try container.encode(ConfigurationAttributeName.setter, forKey: .name)
            try container.encode(value, forKey: .value)
        }
    }
}

extension ConfigurationAttributeTarget: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "__self__":
            self = .`self`
        case let name:
            self = .dependency(name: name)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .`self`:
            try container.encode("__self__")
        case .dependency(let name):
            try container.encode(name)
        }
    }
}

extension ConfigurationAttributeName: Codable {
    
    private enum CompactConfigurationAttributeName: String, Codable {
        case isIsolated = "i"
        case customBuilder = "b"
        case scope = "s"
        case doesSupportObjc = "o"
        case setter = "set"
        
        init(_ value: ConfigurationAttributeName) {
            switch value {
            case .customBuilder:
                self = .customBuilder
            case .isIsolated:
                self = .isIsolated
            case .scope:
                self = .scope
            case .doesSupportObjc:
                self = .doesSupportObjc
            case .setter:
                self = .setter
            }
        }
        
        var unzip: ConfigurationAttributeName {
            switch self {
            case .customBuilder:
                return .customBuilder
            case .doesSupportObjc:
                return .doesSupportObjc
            case .isIsolated:
                return .isIsolated
            case .scope:
                return .scope
            case .setter:
                return .setter
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(CompactConfigurationAttributeName.self).unzip
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CompactConfigurationAttributeName(self))
    }
}

extension Scope: Codable {
    
    private enum CompactScope: String, Codable {
        case transient = "t"
        case container = "c"
        case weak = "w"
        case lazy = "l"
        
        init(_ value: Scope) {
            switch value {
            case .transient:
                self = .transient
            case .container:
                self = .container
            case .weak:
                self = .weak
            case .lazy:
                self = .lazy
            }
        }
        
        var unzip: Scope {
            switch self {
            case .transient:
                return .transient
            case .container:
                return .container
            case .weak:
                return .weak
            case .lazy:
                return .lazy
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(CompactScope.self).unzip
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CompactScope(self))
    }
}

extension AccessLevel: Codable {
    
    private enum CompactAccessLevel: String, Codable {
        case `public` = "p"
        case `open` = "o"
        case `internal` = "i"
        
        init(_ value: AccessLevel) {
            switch value {
            case .`public`:
                self = .`public`
            case .`open`:
                self = .`open`
            case .`internal`:
                self = .`internal`
            }
        }
        
        var unzip: AccessLevel {
            switch self {
            case .`public`:
                return .`public`
            case .`open`:
                return .`open`
            case .`internal`:
                return .`internal`
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(CompactAccessLevel.self).unzip
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CompactAccessLevel(self))
    }
}

extension ConcreteType: Codable {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case genericNames = "g"
        case isOptional = "o"
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            genericNames: try container.decode([String].self, forKey: .genericNames),
            isOptional: try container.decode(Bool.self, forKey: .isOptional)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(genericNames, forKey: .genericNames)
        try container.encode(isOptional, forKey: .isOptional)
    }
}

extension AbstractType: Codable {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case genericNames = "g"
        case isOptional = "o"
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            genericNames: try container.decode([String].self, forKey: .genericNames),
            isOptional: try container.decode(Bool.self, forKey: .isOptional)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(genericNames, forKey: .genericNames)
        try container.encode(isOptional, forKey: .isOptional)
    }
}


extension TokenBox: Codable {
    
    private enum Key: String, CodingKey {
        case value = "v"
        case offset = "o"
        case length = "ln"
        case line = "l"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        value = try container.decode(T.self, forKey: .value)
        offset = try container.decode(Int.self, forKey: .offset)
        length = try container.decode(Int.self, forKey: .length)
        line = try container.decode(Int.self, forKey: .line)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(value, forKey: .value)
        try container.encode(offset, forKey: .offset)
        try container.encode(length, forKey: .length)
        try container.encode(line, forKey: .line)
    }
}

extension RegisterAnnotation {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case type = "t"
        case protocolTypes = "p"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ConcreteType.self, forKey: .type)
        protocolTypes = try container.decode(Set<AbstractType>.self, forKey: .protocolTypes)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(protocolTypes, forKey: .protocolTypes)
    }
}

extension ReferenceAnnotation {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case types = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        name = try container.decode(String.self, forKey: .name)
        types = try container.decode(Set<AbstractType>.self, forKey: .types)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(types, forKey: .types)
    }
}

extension ParameterAnnotation {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case type = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ConcreteType.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
    }
}

extension ConfigurationAnnotation {
    
    private enum Key: String, CodingKey {
        case attribute = "a"
        case target = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        attribute = try container.decode(ConfigurationAttribute.self, forKey: .attribute)
        target = try container.decode(ConfigurationAttributeTarget.self, forKey: .target)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(target, forKey: .target)
    }
}

extension ImportDeclaration {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        moduleName = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(moduleName)
    }
}

extension InjectableType {
    
    private enum Key: String, CodingKey {
        case type = "t"
        case accessLevel = "a"
        case doesSupportObjc = "o"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        type = try container.decode(ConcreteType.self, forKey: .type)
        accessLevel = try container.decode(AccessLevel.self, forKey: .accessLevel)
        doesSupportObjc = try container.decode(Bool.self, forKey: .doesSupportObjc)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(type, forKey: .type)
        try container.encode(accessLevel, forKey: .accessLevel)
        try container.encode(doesSupportObjc, forKey: .doesSupportObjc)
    }
}

extension EndOfInjectableType {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        description = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension AnyDeclaration {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        description = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension EndOfAnyDeclaration {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        description = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension LexerCache.Cache: Codable {
    
    private enum Key: String, CodingKey {
        case version = "i"
        case values = "v"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        version = try container.decode(String.self, forKey: .version)
        values = try container.decode([String: LexerCache.Cache.Value].self, forKey: .values)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(version, forKey: .version)
        try container.encode(values, forKey: .values)
    }
}

extension LexerCache.Cache.Value: Codable {
    
    private enum Key: String, CodingKey {
        case tokens = "t"
        case lastUpdate = "u"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        tokens = try container.decode([LexerCache.Cache.Token].self, forKey: .tokens)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(lastUpdate, forKey: .lastUpdate)
    }
}

extension LexerCache.Cache.Token: Codable {
    
    private enum TokenType: String, Codable {
        case registration = "reg"
        case reference = "ref"
        case parameter = "p"
        case configuration = "c"
        case `import` = "i"
        case type = "t"
        case typeEnd = "te"
        case anyDeclaration = "a"
        case anyDeclarationEnd = "ae"
    }
    
    private enum Key: String, CodingKey {
        case type = "t"
        case value = "v"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        switch try container.decode(TokenType.self, forKey: .type) {
        case .registration:
            value = try container.decode(TokenBox<RegisterAnnotation>.self, forKey: .value)
        case .parameter:
            value = try container.decode(TokenBox<ParameterAnnotation>.self, forKey: .value)
        case .reference:
            value = try container.decode(TokenBox<ReferenceAnnotation>.self, forKey: .value)
        case .configuration:
            value = try container.decode(TokenBox<ConfigurationAnnotation>.self, forKey: .value)
        case .`import`:
            value = try container.decode(TokenBox<ImportDeclaration>.self, forKey: .value)
        case .type:
            value = try container.decode(TokenBox<InjectableType>.self, forKey: .value)
        case .typeEnd:
            value = try container.decode(TokenBox<EndOfInjectableType>.self, forKey: .value)
        case .anyDeclaration:
            value = try container.decode(TokenBox<AnyDeclaration>.self, forKey: .value)
        case .anyDeclarationEnd:
            value = try container.decode(TokenBox<EndOfAnyDeclaration>.self, forKey: .value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch value {
        case let value as TokenBox<RegisterAnnotation>:
            try container.encode(TokenType.registration, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<ParameterAnnotation>:
            try container.encode(TokenType.parameter, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<ReferenceAnnotation>:
            try container.encode(TokenType.reference, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<ConfigurationAnnotation>:
            try container.encode(TokenType.configuration, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<ImportDeclaration>:
            try container.encode(TokenType.`import`, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<InjectableType>:
            try container.encode(TokenType.type, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<EndOfInjectableType>:
            try container.encode(TokenType.typeEnd, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<AnyDeclaration>:
            try container.encode(TokenType.anyDeclaration, forKey: .type)
            try container.encode(value, forKey: .value)
        case let value as TokenBox<EndOfAnyDeclaration>:
            try container.encode(TokenType.anyDeclarationEnd, forKey: .type)
            try container.encode(value, forKey: .value)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unknown type."))
        }
    }
}
