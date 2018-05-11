//
//  SourceKitTypeDeclaration.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

struct SourceKitDeclaration {
    
    let offset: Int
    let length: Int
    let name: String
    let isInjectable: Bool
    let hasBody: Bool
    let accessLevel: AccessLevel
    
    init?(_ dictionary: [String: Any]) {
        
        guard let kindString = dictionary[SwiftDocKey.kind.rawValue] as? String,
              let kind = SwiftDeclarationKind(rawValue: kindString) else {
            return nil
        }
        
        let inheritedTypes: [String]
        if let inheritedTypeDicts = dictionary[SwiftDocKey.inheritedtypes.rawValue] as? [[String: Any]] {
            inheritedTypes = inheritedTypeDicts.flatMap { $0[SwiftDocKey.name.rawValue] as? String }
        } else {
            inheritedTypes = []
        }

        switch kind {
        case .class,
             .struct:
            isInjectable = true

        case .extension where inheritedTypes.contains("Injectable"):
            isInjectable = true
            
        default:
            isInjectable = false
        }
        
        guard let offset = dictionary[SwiftDocKey.offset.rawValue] as? Int64 else {
            return nil
        }
        self.offset = Int(offset)
        
        guard let length = dictionary[SwiftDocKey.length.rawValue] as? Int64 else {
            return nil
        }
        self.length = Int(length)
        
        guard let name = dictionary[SwiftDocKey.name.rawValue] as? String else {
            return nil
        }
        self.name = name
        
        hasBody = dictionary.keys.contains(SwiftDocKey.bodyOffset.rawValue)
        
        if let attributeKindString = dictionary["key.accessibility"] as? String {
            self.accessLevel = AccessLevel(attributeKindString)
        } else {
            accessLevel = .default
        }
    }
}

// MARK: - Conversion

extension SourceKitDeclaration {
    
    var toToken: AnyTokenBox {
        if isInjectable {
            return TokenBox(value: InjectableType(name: name, accessLevel: accessLevel), offset: offset, length: length, line: -1)
        } else {
            return TokenBox(value: AnyDeclaration(), offset: offset, length: length, line: -1)
        }
    }
    
    var endToken: AnyTokenBox? {
        guard hasBody == true else {
            return nil
        }
        
        let offset = self.offset + length - 1
        if isInjectable {
            return TokenBox(value: EndOfInjectableType(), offset: offset, length: 1, line: -1)
        } else {
            return TokenBox(value: EndOfAnyDeclaration(), offset: offset, length: 1, line: -1)
        }
    }
}

private extension AccessLevel {

    init(_ stringValue: String) {
        switch stringValue {
        case "source.lang.swift.accessibility.internal":
            self = .internal
        case "source.lang.swift.accessibility.public":
            self = .public
        default:
            self = .default
        }
    }
}

