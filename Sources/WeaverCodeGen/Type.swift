//
//  Type.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

/// Representation of any Swift type
public struct Type: AutoHashable, AutoEquatable {

    /// Type name
    public let name: String
    
    /// Names of the generic parameters
    public let genericNames: [String]
    
    public let isOptional: Bool
    
    public let generics: String
    
    init?(_ string: String) throws {
        guard let matches = try NSRegularExpression(pattern: "^(\(Patterns.typeName))$").matches(in: string) else {
            return nil
        }

        let name = matches[1]

        let isOptional = matches[0].hasSuffix("?")
        
        let genericNames: [String]
        if matches.count > 2 {
            let characterSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "<>,"))
            genericNames = matches[2]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: characterSet) }
        } else {
            genericNames = []
        }
        
        self.init(name: name, genericNames: genericNames, isOptional: isOptional)
    }
    
    init(name: String,
         genericNames: [String] = [],
         isOptional: Bool = false) {

        self.name = name
        self.genericNames = genericNames
        self.isOptional = isOptional
        
        generics = "\(genericNames.isEmpty ? "" : "<\(genericNames.joined(separator: ", "))>")"
    }
}

// MARK: - Index

struct TypeIndex: AutoHashable, AutoEquatable {

    let value: String
    
    fileprivate init(type: Type) {
        value = "\(type.name)\(type.isOptional ? "?" : "")"
    }
}

// MARK: - Description

extension Type: CustomStringConvertible {
    
    public var description: String {
        return "\(name)\(generics)\(isOptional ? "?" : "")"
    }
    
    var indexKey: String {
        return "\(name)\(isOptional ? "?" : "")"
    }
    
    var index: TypeIndex {
        return TypeIndex(type: self)
    }
}
