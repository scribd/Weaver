//
//  SwiftType.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

public class AnyType: Hashable, CustomStringConvertible {
    
    /// Type name
    var name: String
    
    /// Names of the generic parameters
    var genericNames: [String]
    
    /// Defines if type is optional or not
    var isOptional: Bool
    
    init(name: String,
         genericNames: [String] = [],
         isOptional: Bool = false) {
        
        self.name = name
        self.genericNames = genericNames
        self.isOptional = isOptional
    }
    
    public var description: String {
        let generics = "\(genericNames.isEmpty ? "" : "<\(genericNames.joined(separator: ", "))>")"
        return "\(name)\(generics)\(isOptional ? "?" : "")"
    }
    
    public static func == (lhs: AnyType, rhs: AnyType) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.genericNames == rhs.genericNames else { return false }
        guard lhs.isOptional == rhs.isOptional else { return false }
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(genericNames)
        hasher.combine(isOptional)
    }
}

public final class ConcreteType: AnyType {
    
    var abstractType: AbstractType {
        return AbstractType(name: name, genericNames: genericNames, isOptional: isOptional)
    }
}

public final class AbstractType: AnyType {
    
    var concreteType: ConcreteType {
        return ConcreteType(name: name, genericNames: genericNames, isOptional: isOptional)
    }
}

// MARK: - Parsing

extension AnyType {
    
    convenience init?(_ string: String) throws {
        if let matches = NSRegularExpression.genericType.matches(in: string) {
            let name = matches[1]
            
            let isOptional = matches[0].hasSuffix("?")
            
            let genericNames: [String]
            if let genericTypesMatches = NSRegularExpression.genericTypePart.matches(in: matches[0]) {
                let characterSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "<>,"))
                genericNames = genericTypesMatches[0]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: characterSet) }
            } else {
                genericNames = []
            }
            
            self.init(name: name, genericNames: genericNames, isOptional: isOptional)
        } else if let match = NSRegularExpression.arrayTypeWithNamedGroups.firstMatch(in: string),
            let wholeType = match.rangeString(at: 0, in: string),
            let valueType = match.rangeString(withName: "value", in: string) {
            
            let name = "Array"
            let isOptional = wholeType.hasSuffix("?")
            let genericNames = [valueType]
            
            self.init(name: name, genericNames: genericNames, isOptional: isOptional)
        } else if let match = NSRegularExpression.dictTypeWithNamedGroups.firstMatch(in: string),
            let wholeType = match.rangeString(at: 0, in: string),
            let keyType = match.rangeString(withName: "key", in: string),
            let valueType = match.rangeString(withName: "value", in: string) {
            
            let name = "Dictionary"
            let isOptional = wholeType.hasSuffix("?")
            let genericNames = [keyType, valueType]
            
            self.init(name: name, genericNames: genericNames, isOptional: isOptional)
        } else {
            return nil
        }
    }
}
