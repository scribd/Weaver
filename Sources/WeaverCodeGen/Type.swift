//
//  SwiftType.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

public protocol TypeKind {}
public enum Void: TypeKind {}
public enum ConcreteTypeKind: TypeKind {}
public enum AbstractTypeKind: TypeKind {}

public typealias ConcreteType = AnyType<ConcreteTypeKind>
public typealias AbstractType = AnyType<AbstractTypeKind>

public struct AnyType<T: TypeKind>: Hashable {
    
    public let name: String
    
    public let parameterTypes: [CompositeType]
    
    init(name: String,
         parameterTypes: [CompositeType] = []) {
        
        self.name = name
        self.parameterTypes = parameterTypes
    }
    
    var isOptional: Bool {
        return name == "Optional"
    }
}

extension AnyType {
    
    var abstractType: AbstractType {
        return AbstractType(name: name, parameterTypes: parameterTypes)
    }
    
    var concreteType: ConcreteType {
        return ConcreteType(name: name, parameterTypes: parameterTypes)
    }
    
    var voidType: AnyType<Void> {
        return AnyType<Void>(name: name, parameterTypes: parameterTypes)
    }
}

public indirect enum CompositeType: Hashable, CustomStringConvertible {
    
    public struct Closure: Hashable, CustomStringConvertible {
        
        public let tuple: [TupleParameter]
        
        public let returnType: CompositeType
    }

    public struct TupleParameter: Hashable, CustomStringConvertible {
        
        public let alias: String?
        
        public let name: String?
        
        public let type: CompositeType
    }
    
    case components([AnyType<Void>])
    case closure(Closure)
    case tuple([TupleParameter])
    
    init(_ stringValue: String) throws {
        let parser = try TypeParser(stringValue)
        self = try parser.parse()
    }
}

// MARK: - Description

extension AnyType {

    public var description: String {
        let generics = "\(parameterTypes.isEmpty ? "" : "<\(parameterTypes.map { $0.description }.joined(separator: ", "))>")"
        return "\(name)\(generics)"
    }
}

extension CompositeType.TupleParameter {
    
    public var description: String {
        let alias = self.alias.flatMap { "\($0) " } ?? String()
        let name = self.name.flatMap { "\($0): " } ?? String()
        return "\(alias)\(name)\(type)"
    }
}

extension CompositeType.Closure {
    
    public var description: String {
        return "(\(tuple.map { $0.description }.joined(separator: ", "))) -> \(returnType)"
    }
}

extension CompositeType {
    
    public var description: String {
        switch self {
        case .closure(let closure):
            return closure.description
        case .components(let components):
            return components.lazy.map { $0.description }.sorted().joined(separator: " & ")
        case .tuple(let parameters):
            return "(\(parameters.lazy.map { $0.description }.joined(separator: ", ")))"
        }
    }
    
    func singleType<T>(or error: Error) throws -> AnyType<T> {
        switch self {
        case .components(let components) where components.count == 1:
            return AnyType<T>(name: components.first!.name, parameterTypes: components.first!.parameterTypes)
        case .tuple,
             .closure,
             .components:
            throw error
        }
    }
    
    func components<T>(or error: Error) throws -> Set<AnyType<T>> {
        switch self {
        case .components(let components):
            return Set(components.lazy.map { AnyType<T>(name: $0.name, parameterTypes: $0.parameterTypes) })
        case .closure,
             .tuple:
            throw error
        }
    }
}

// MARK: - Parsing

private final class TypeParser {
    
    enum Delimiter: String {
        case tupleOpen = "("
        case tupleClose = ")"
        case genericOpen = "<"
        case genericClose = ">"
        case unwrap = "?"
        case closureArrow = "->"
        case comma = ","
        case colon = ":"
        case arrayOrDictOpen = "["
        case arrayOrDictClose = "]"
        case and = "&"
    }
    
    enum Token: Equatable {
        case delimiter(Delimiter)
        case typeName(String)
    }
    
    private let string: String
 
    private var index = 0
    private var tokens = [Token]()
    
    init(_ string: String) throws {
        self.string = string
        tokens = try tokenize()
    }
    
    // MARK: - Lexer
    
    private func tokenize() throws -> [Token] {
        
        let acceptedNameChars = CharacterSet(charactersIn: "._").union(.alphanumerics)
        
        var iterator = string.makeIterator()
        var currentTypeName = String()
        var buffer = ""
        var tokens = [Token]()
        
        let saveCurrentTypeName = {
            if currentTypeName.isEmpty == false {
                tokens.append(.typeName(currentTypeName))
                currentTypeName.removeAll()
            }
        }
        
        while let currentChar = iterator.next() {
            if currentChar == "-" {
                buffer += String(currentChar)
            } else if buffer.last == "-" && currentChar == ">" {
                buffer.removeAll()
                saveCurrentTypeName()
                tokens.append(.delimiter(.closureArrow))
            } else if let delimiter = Delimiter(rawValue: String(currentChar)) {
                saveCurrentTypeName()
                tokens.append(.delimiter(delimiter))
            } else if currentChar.isWhitespace || currentChar.isNewline {
                saveCurrentTypeName()
            } else if acceptedNameChars.isStrictSuperset(of: CharacterSet(charactersIn: String(currentChar))) {
                currentTypeName += String(currentChar)
            } else {
                throw TokenError.invalidTokenInType(type: string, token: String(currentChar))
            }
        }
        
        guard buffer.isEmpty else {
            throw TokenError.invalidTokenInType(type: string, token: String(buffer.first!))
        }
        
        saveCurrentTypeName()
        
        return tokens
    }
    
    // MARK: - Parse
    
    private var currentToken: Token? {
        return index < tokens.count ? tokens[index] : nil
    }
    
    private func consumeToken() {
        index += 1
    }
    
    private func revertToken() {
        guard index - 1 >= 0 else { return }
        index -= 1
    }
    
    private func consumeTokenOrBail(_ token: Token) throws {
        guard currentToken == token else {
            switch currentToken {
            case .delimiter(let delimiter):
                throw TokenError.invalidTokenInType(type: string, token: delimiter.rawValue)
            case .typeName(let name):
                throw TokenError.invalidTokenInType(type: string, token: name)
            default:
                throw TokenError.invalidTokenInType(type: string, token: nil)
            }
        }
        consumeToken()
    }
    
    @discardableResult
    private func consumeToken(_ token: Token) -> Bool {
        guard currentToken == token else { return false }
        consumeToken()
        return true
    }
    
    func parse() throws -> CompositeType {
        let type: CompositeType

        switch currentToken {
        case .typeName:
            var components = [AnyType<Void>]()
            repeat {
                components.append(try parseComponent())
            } while consumeToken(.delimiter(.and))
            type = .components(components)
            
        case .delimiter(.arrayOrDictOpen):
            consumeToken()
            let elementType = try parse()
            switch currentToken {
            case .delimiter(.arrayOrDictClose):
                consumeToken()
                type = .components([AnyType(name: "Array", parameterTypes: [elementType])])
            
            case .delimiter(.colon):
                consumeToken()
                let keyType = elementType
                let valueType = try parse()
                try consumeTokenOrBail(.delimiter(.arrayOrDictClose))
                type = .components([AnyType(name: "Dictionary", parameterTypes: [keyType, valueType])])

            case .delimiter(let delimiter):
                throw TokenError.invalidTokenInType(type: string, token: delimiter.rawValue)

            case .typeName(let typename):
                throw TokenError.invalidTokenInType(type: string, token: typename)

            case .none:
                throw TokenError.invalidTokenInType(type: string, token: nil)
            }
            
        case .delimiter(.tupleOpen):
            consumeToken()
            var parameters = [CompositeType.TupleParameter]()
            if consumeToken(.delimiter(.tupleClose)) == false {
                repeat {
                    var alias: String?
                    var name: String?
                    if case .typeName(let value) = currentToken {
                        consumeToken()
                        alias = value
                    }
                    if currentToken == .delimiter(.tupleClose) ||
                       currentToken == .delimiter(.comma) ||
                       currentToken == .delimiter(.colon) {
                        alias = nil
                        revertToken()
                    }
                    if case .typeName(let value) = currentToken {
                        consumeToken()
                        name = value
                    }
                    if currentToken == .delimiter(.tupleClose) ||
                       currentToken == .delimiter(.comma) {
                        name = nil
                        revertToken()
                    }
                    if name != nil {
                        try consumeTokenOrBail(.delimiter(.colon))
                    }
                    let type = try parse()
                    parameters.append(CompositeType.TupleParameter(alias: alias, name: name, type: type))
                } while consumeToken(.delimiter(.comma))
                try consumeTokenOrBail(.delimiter(.tupleClose))
            }
            
            switch currentToken {
            case .delimiter(.closureArrow):
                consumeToken()
                let returnType = try parse()
                type = .closure(CompositeType.Closure(tuple: parameters, returnType: returnType))

            case .none:
                type = .tuple(parameters)

            case .delimiter(let delimiter):
                throw TokenError.invalidTokenInType(type: string, token: delimiter.rawValue)

            case .typeName(let name):
                throw TokenError.invalidTokenInType(type: string, token: name)
            }
            
        case .delimiter(let delimiter):
            throw TokenError.invalidTokenInType(type: string, token: delimiter.rawValue)

        case .none:
            throw TokenError.invalidTokenInType(type: string, token: nil)
        }
        
        return parseUnwraps(for: type)
    }
    
    private func parseComponent() throws -> AnyType<Void> {
        switch currentToken {
        case .typeName(let name):
            consumeToken()
            var parameters = [CompositeType]()
            if consumeToken(.delimiter(.genericOpen)) {
                repeat {
                    parameters.append(try parse())
                } while consumeToken(.delimiter(.comma))
                try consumeTokenOrBail(.delimiter(.genericClose))
            }
            return AnyType(name: name, parameterTypes: parameters)
        
        case .delimiter(let delimiter):
            throw TokenError.invalidTokenInType(type: string, token: delimiter.rawValue)

        case .none:
            throw TokenError.invalidTokenInType(type: string, token: nil)
        }
    }
    
    private func parseUnwraps(for type: CompositeType) -> CompositeType {
        if consumeToken(.delimiter(.unwrap)) {
            return .components([AnyType<Void>(name: "Optional", parameterTypes: [parseUnwraps(for: type)])])
        } else {
            return type
        }
    }
}
