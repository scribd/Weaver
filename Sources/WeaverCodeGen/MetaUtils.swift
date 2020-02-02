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
    static let abstractType = TypeIdentifier(name: "AbstractType")
    static let concreteType = TypeIdentifier(name: "ConcreteType")
    static let resolver = TypeIdentifier(name: "Resolver")

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
    static let resolver = Variable(name: "resolver")
    static let builders = Variable(name: "builders")
}

extension TypeWrapper {
    
    var typeID: TypeIdentifier {
        return TypeIdentifier(name: .custom(description))
    }

    var dependencyResolverTypeID: TypeIdentifier {
        let valueTypeName = value.toTypeName
        let underscore = valueTypeName.contains("_") ? "_" : String()
        return TypeIdentifier(name: "\(valueTypeName)\(underscore)DependencyResolver")
    }

    var internalDependencyResolverTypeID: TypeIdentifier {
        let valueTypeName = value.toTypeName
        let underscore = valueTypeName.contains("_") ? "_" : String()
        return TypeIdentifier(name: "\(valueTypeName)\(underscore)InternalDependencyResolver")
    }

    var dependencyResolverProxyTypeID: TypeIdentifier {
        let valueTypeName = value.toTypeName
        let underscore = valueTypeName.contains("_") ? "_" : String()
        return TypeIdentifier(name: "\(valueTypeName)\(underscore)DependencyResolverProxy")
    }

    var dependencyResolverVariable: Variable {
        let valueTypeName = value.toTypeName
        let underscore = valueTypeName.contains("_") ? "_" : String()
        return Variable(name: "\(valueTypeName.variableCased)\(underscore)DependencyResolver")
    }
    
    var publicDependencyResolverVariable: Variable {
        return Variable(name: "public\(dependencyResolverVariable.name.typeCase)")
    }
    
    var inputDependencyResolverTypeID: TypeIdentifier {
        let valueTypeName = value.toTypeName
        let underscore = valueTypeName.contains("_") ? "_" : String()
        return TypeIdentifier(name: "\(valueTypeName)\(underscore)InputDependencyResolver")
    }
    
    var dependencyBuilderVariable: Variable {
        return Variable(name: "build\(name ?? toTypeName)")
    }
     
    var toTypeName: String {
        return value.toTypeName
    }
}

private extension AnyType {
    
    var toTypeName: String {
        let genericNames = parameterTypes.isEmpty == false ?
            "_\(parameterTypes.map { $0.toTypeName }.joined(separator: "_"))" : String()
        return "\(name)\(genericNames)"
    }
}

extension CompositeType {
    
    var toTypeName: String {
        switch self {
        case .components(let components):
            return components.lazy.map { $0.toTypeName }.sorted().joined(separator: "_")
        case .closure(let closure):
            return closure.toTypeName
        case .tuple(let parameters):
            return parameters.lazy.map { $0.toTypeName }.joined(separator: "_")
        }
    }
}

extension Closure {
    
    var toTypeName: String {
        return tuple.lazy.map { $0.toTypeName }.joined(separator: "_") + returnType.toTypeName
    }
}

extension TupleComponent {
    
    var toTypeName: String {
        let alias = self.alias.flatMap { "\($0)_" } ?? String()
        let name = self.name.flatMap { "\($0)_" } ?? String()
        return "\(alias)\(name)\(type)"
    }
}

extension Dependency.`Type` {
    
    var abstractTypeID: TypeIdentifier? {
        switch self {
        case .abstract(let type),
             .full(_, let type):
            return type.typeID
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
