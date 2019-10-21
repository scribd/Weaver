//
//  SwiftType.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

/// Representation of any Swift type
public struct SwiftType: Hashable, Equatable {

    /// SwiftType name
    public let name: String
    
    /// Names of the generic parameters
    public let genericNames: [String]
    
    public let isOptional: Bool
    
    public let generics: String
    
    init?(_ string: String) throws {
        if let matches = try NSRegularExpression(pattern: "^(\(Patterns.genericType))$").matches(in: string) {
            let name = matches[1]
            
            let isOptional = matches[0].hasSuffix("?")
            
            let genericNames: [String]
            if let genericTypesMatches = try NSRegularExpression(pattern: "(\(Patterns.genericTypePart))").matches(in: matches[0]) {
                let characterSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "<>,"))
                genericNames = genericTypesMatches[0]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: characterSet) }
            } else {
                genericNames = []
            }
            
            self.init(name: name, genericNames: genericNames, isOptional: isOptional)
        } else if let match = try NSRegularExpression(pattern: "^(\(Patterns.arrayTypeWithNamedGroups))$").firstMatch(in: string),
                  let wholeType = match.rangeString(at: 0, in: string),
                  let valueType = match.rangeString(withName: "value", in: string) {

            let name = "Array"
            let isOptional = wholeType.hasSuffix("?")
            let genericNames = [valueType]

            self.init(name: name, genericNames: genericNames, isOptional: isOptional)
        } else if let match = try NSRegularExpression(pattern: "^(\(Patterns.dictTypeWithNamedGroups))$").firstMatch(in: string),
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

struct SwiftTypeIndex: Hashable, Equatable {

    let value: String
    
    init(type: SwiftType) {
        value = "\(type.name)\(type.isOptional ? "?" : "")"
    }
}

// MARK: - Description

extension SwiftType: CustomStringConvertible {
    
    public var description: String {
        return "\(name)\(generics)\(isOptional ? "?" : "")"
    }
    
    var indexKey: String {
        return "\(name)\(isOptional ? "?" : "")"
    }
    
    var index: SwiftTypeIndex {
        return SwiftTypeIndex(type: self)
    }
}
