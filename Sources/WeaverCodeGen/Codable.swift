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

extension CompositeType: Codable {
    
    private enum Key: String, CodingKey {
        case key = "k"
        case value = "v"
    }
    
    private enum ValueKey: String, Codable {
        case components = "c"
        case closure = "cl"
        case tuple = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        switch try container.decode(ValueKey.self, forKey: .key) {
        case .components:
            self = .components(try container.decode([AnyType].self, forKey: .value))
        case .closure:
            self = .closure(try container.decode(Closure.self, forKey: .value))
        case .tuple:
            self = .tuple(try container.decode([TupleComponent].self, forKey: .value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .closure(let closure):
            try container.encode(ValueKey.closure, forKey: .key)
            try container.encode(closure, forKey: .value)
        case .components(let components):
            try container.encode(ValueKey.components, forKey: .key)
            try container.encode(components, forKey: .value)
        case .tuple(let parameters):
            try container.encode(ValueKey.tuple, forKey: .key)
            try container.encode(parameters, forKey: .value)
        }
    }
}

extension AnyType: Codable {
    
    private enum Key: String, CodingKey {
        case name = "n"
        case parameterTypes = "g"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        name = try container.decode(String.self, forKey: .name)
        parameterTypes = try container.decode([CompositeType].self, forKey: .parameterTypes)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name, forKey: .name)
        try container.encode(parameterTypes, forKey: .parameterTypes)
    }
}

extension TypeWrapper: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension Closure: Codable {
    
    private enum Key: String, CodingKey {
        case tuple = "t"
        case returnType = "r"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        tuple = try container.decode([TupleComponent].self, forKey: .tuple)
        returnType = try container.decode(CompositeType.self, forKey: .returnType)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(tuple, forKey: .tuple)
        try container.encode(returnType, forKey: .returnType)
    }
}

extension TupleComponent: Codable {
    
    private enum Key: String, CodingKey {
        case alias = "a"
        case name = "n"
        case type = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decode(CompositeType.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(alias, forKey: .alias)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
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

extension AnnotationStyle: Codable {
    
    private enum CompactAnnotationStyle: String, Codable {
        case comment = "c"
        case propertyWrapper = "p"
        
        init(_ value: AnnotationStyle) {
            switch value {
            case .comment:
                self = .comment
            case .propertyWrapper:
                self = .propertyWrapper
            }
        }
        
        var unzip: AnnotationStyle {
            switch self {
            case .comment:
                return .comment
            case .propertyWrapper:
                return .propertyWrapper
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(CompactAnnotationStyle.self).unzip
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CompactAnnotationStyle(self))
    }
}

extension RegisterAnnotation {
    
    private enum Key: String, CodingKey {
        case style = "s"
        case name = "n"
        case type = "t"
        case abstractTypes = "a"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        style = try container.decode(AnnotationStyle.self, forKey: .style)
        name = try container.decode(String.self, forKey: .name)
        type = TypeWrapper(value: try container.decode(AnyType.self, forKey: .type))
        abstractTypes = Set(try container.decode(Set<AnyType>.self, forKey: .abstractTypes).lazy.map {
            TypeWrapper(value: $0)
        })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(style, forKey: .style)
        try container.encode(name, forKey: .name)
        try container.encode(type.value, forKey: .type)
        try container.encode(abstractTypes.map { $0.value }, forKey: .abstractTypes)
    }
}

extension ReferenceAnnotation {
    
    private enum Key: String, CodingKey {
        case style = "s"
        case name = "n"
        case types = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        style = try container.decode(AnnotationStyle.self, forKey: .style)
        name = try container.decode(String.self, forKey: .name)
        types = Set(try container.decode(Set<AnyType>.self, forKey: .types).lazy.map {
            TypeWrapper(value: $0)
        })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(style, forKey: .style)
        try container.encode(name, forKey: .name)
        try container.encode(types.map { $0.value }, forKey: .types)
    }
}

extension ParameterAnnotation {
    
    private enum Key: String, CodingKey {
        case style = "s"
        case name = "n"
        case type = "t"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        style = try container.decode(AnnotationStyle.self, forKey: .style)
        name = try container.decode(String.self, forKey: .name)
        type = TypeWrapper(value: try container.decode(AnyType.self, forKey: .type))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(style, forKey: .style)
        try container.encode(name, forKey: .name)
        try container.encode(type.value, forKey: .type)
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
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        type = TypeWrapper(value: try container.decode(AnyType.self, forKey: .type))
        accessLevel = try container.decode(AccessLevel.self, forKey: .accessLevel)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(type.value, forKey: .type)
        try container.encode(accessLevel, forKey: .accessLevel)
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

extension DependencyGraph: Encodable {
    
    private enum Key: CodingKey {
        case imports
        case abstractTypes
        case concreteTypes
        case orphinConcreteTypes
        case dependencyContainers
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(imports, forKey: .imports)
        
        try container.encode(abstractTypes, forKey: .abstractTypes)
        try container.encode(concreteTypes, forKey: .concreteTypes)
        try container.encode(orphinConcreteTypes, forKey: .orphinConcreteTypes)
        try container.encode(dependencyContainers, forKey: .dependencyContainers)
    }
}

extension Dependency.`Type`: Encodable {
    
    private enum Key: CodingKey {
        case abstract
        case concrete
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)

        switch self {
        case .abstract(let type):
            try container.encode([type], forKey: .abstract)
        case .concrete(let type):
            try container.encode(type, forKey: .concrete)
        case .full(let concrete, let abstract):
            try container.encode(concrete, forKey: .concrete)
            try container.encode(abstract, forKey: .abstract)
        }
    }
}
