//
//  MetaUtils.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 11/25/19.
//

import Foundation
import Meta

extension TypeIdentifier {
    
    static let mainDependencyContainer = TypeIdentifier(name: "MainDependencyContainer")
    static let mainDependencyResolverStub = TypeIdentifier(name: "MainDependencyResolverStub")
    static let anyObject = TypeIdentifier(name: "AnyObject")
    static let nsObject = TypeIdentifier(name: "NSObject")

    static func builder(of typeID: TypeIdentifier) -> TypeIdentifier {
        return TypeIdentifier(name: "Builder").adding(genericParameter: typeID)
    }
}

extension Variable {
    
    static let _self = Variable(name: "_self")
    static let __self = Variable(name: "__self")
    static let __mainSelf = Variable(name: "__mainSelf")
    static let source = Variable(name: "source")
    static let value = Variable(name: "_value")
    static let proxySelf = Variable(name: "value")
}

extension AnyType {
    
    var typeID: TypeIdentifier {
        let value = TypeIdentifier(name: name).with(genericParameters: genericNames.map { TypeIdentifier(name: $0) })
        if isOptional {
            return .optional(wrapped: value)
        } else {
            return value
        }
    }

    var dependencyResolverTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(name)DependencyResolver")
    }
    
    var dependencyResolverProxyTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(name)DependencyResolverProxy")
    }

    var dependencyResolverVariable: Variable {
        return Variable(name: "\(name.variableCased)DependencyResolver")
    }
    
    var inputDependencyResolverTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(name)InputDependencyResolver")
    }
    
    var toTypeName: String {
        let optional = isOptional ? "Optional_" : String()
        let genericNames = self.genericNames.isEmpty == false ?
            "_\(self.genericNames.joined(separator: "_"))" : String()
        return "\(optional)\(name)\(genericNames)"
    }
}

extension Dependency.`Type` {
    
    var abstractTypeID: TypeIdentifier? {
        switch self {
        case .abstract(let types),
             .full(_, let types):
            return .and(types.lazy.sorted { $0.description < $1.description }.map { $0.typeID })
        case .concrete:
            return nil
        }
    }
    
    var concreteTypeID: TypeIdentifier? {
        switch self {
        case .concrete(let type),
             .full(let type, _):
            return type.typeID
        case .abstract:
            return nil
        }
    }
    
    var typeID: TypeIdentifier {
        guard let typeID = abstractTypeID ?? concreteTypeID else {
            fatalError("Invalid dependency type.")
        }
        return typeID
    }
}

extension String {
    
    public func camelCased(separators: String = "_", strict: Bool = false) -> String {
        let words = components(separatedBy: CharacterSet(charactersIn: separators))
        return words.enumerated().reduce(String()) {
            $0 + ($1.offset == 0 && strict ? $1.element : $1.element.capitalized)
        }
    }

    var snakeCased: String {
        let range = NSRange(location: 0, length: count)
        return NSRegularExpression.snakeCased.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "$1_$2"
        ).lowercased()
    }
    
    var variableCased: String {
        var _self = self
        var prefix = String()
        var iterator = makeIterator()
        while let char = iterator.next() {
            if char.isUppercase {
                _self.removeFirst()
                prefix.append(char.lowercased())
            } else {
                break
            }
        }
        guard let lastChar = prefix.last else { return self }
        guard prefix.count > 1 else { return prefix + _self }
        prefix.removeLast()
        return prefix + lastChar.uppercased() + _self
    }
    
    var typeCase: String {
        var _self = self
        var iterator = _self.makeIterator()
        var prefix = String()
        while let char = iterator.next() {
            if char == "_" {
                _self.removeFirst()
                prefix.append(char)
            } else {
                break
            }
        }
        guard let firstChar = _self.first else { return String() }
        _self.removeFirst()
        return prefix + firstChar.uppercased() + _self
    }
}
