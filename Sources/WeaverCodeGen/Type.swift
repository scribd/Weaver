//
//  SwiftType.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

public protocol TypeKind {}
public enum ConcreteTypeKind: TypeKind {}
public enum AbstractTypeKind: TypeKind {}

public typealias ConcreteType = TypeWrapper<ConcreteTypeKind>
public typealias AbstractType = TypeWrapper<AbstractTypeKind>

public struct TypeWrapper<T: TypeKind>: Hashable, CustomStringConvertible {

    let value: AnyType
    
    public var description: String {
        return value.description
    }
    
    var abstractType: AbstractType {
        return AbstractType(value: value)
    }
    
    var concreteType: ConcreteType {
        return ConcreteType(value: value)
    }
}

struct AnyType: Hashable {
    
    let name: String
    
    let parameterTypes: [CompositeType]
    
    init(name: String,
         parameterTypes: [CompositeType] = []) {
        
        self.name = name
        self.parameterTypes = parameterTypes
    }
    
    var isOptional: Bool {
        return name == "Optional"
    }
}

struct Closure: Hashable, CustomStringConvertible {
    
    let tuple: [TupleComponent]
    
    let returnType: CompositeType
}

struct TupleComponent: Hashable, CustomStringConvertible {
    
    let alias: String?
    
    let name: String?
    
    let type: CompositeType
}

indirect enum CompositeType: Hashable, CustomStringConvertible {
    
    case components([AnyType])
    case closure(Closure)
    case tuple([TupleComponent])
    
    init(_ stringValue: String) throws {
        let parser = try TypeParser(stringValue)
        self = try parser.parse()
    }
}

// MARK: - Description

extension AnyType {

    var description: String {
        let generics = "\(parameterTypes.isEmpty ? "" : "<\(parameterTypes.map { $0.description }.joined(separator: ", "))>")"
        return "\(name)\(generics)"
    }
}

extension TupleComponent {
    
    var description: String {
        let alias = self.alias.flatMap { "\($0) " } ?? String()
        let name = self.name.flatMap { "\($0): " } ?? String()
        return "\(alias)\(name)\(type)"
    }
}

extension Closure {
    
    var description: String {
        return "(\(tuple.map { $0.description }.joined(separator: ", "))) -> \(returnType)"
    }
}

extension CompositeType {
    
    var description: String {
        switch self {
        case .closure(let closure):
            return closure.description
        case .components(let components):
            return components.lazy.map { $0.description }.sorted().joined(separator: " & ")
        case .tuple(let parameters):
            return "(\(parameters.lazy.map { $0.description }.joined(separator: ", ")))"
        }
    }
    
    func singleType<T>(or error: Error) throws -> TypeWrapper<T> {
        switch self {
        case .components(let components) where components.count == 1:
            return TypeWrapper(value: components.first!)
        case .tuple,
             .closure,
             .components:
            throw error
        }
    }
    
    func components<T>(or error: Error) throws -> Set<TypeWrapper<T>> {
        switch self {
        case .components(let components):
            return Set(components.lazy.map { TypeWrapper(value: $0) })
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
                break
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
            var components = [AnyType]()
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
            var parameters = [TupleComponent]()
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
                    parameters.append(TupleComponent(alias: alias, name: name, type: type))
                } while consumeToken(.delimiter(.comma))
                try consumeTokenOrBail(.delimiter(.tupleClose))
            }
            
            switch currentToken {
            case .delimiter(.closureArrow):
                consumeToken()
                let returnType = try parse()
                type = .closure(Closure(tuple: parameters, returnType: returnType))

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
    
    private func parseComponent() throws -> AnyType {
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
        var type = type
        while consumeToken(.delimiter(.unwrap)) {
            type = .components([AnyType(name: "Optional", parameterTypes: [type])])
        }
        return type
    }
}
