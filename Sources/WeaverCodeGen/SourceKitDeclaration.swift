//
//  SourceKitTypeDeclaration.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

struct SourceKitDeclaration {
    
    enum Constant {
        static let injectableDeclarationKinds: [SwiftDeclarationKind] = [
            .`class`,
            .`struct`
        ]
    }
    
    let offset: Int
    let length: Int
    let name: String
    let isInjectable: Bool
    let hasBody: Bool
    
    init?(_ dictionary: [String: Any]) {
        
        guard let kindString = dictionary[SwiftDocKey.kind.rawValue] as? String,
              let kind = SwiftDeclarationKind(rawValue: kindString) else {
            return nil
        }
        isInjectable = Constant.injectableDeclarationKinds.contains(kind)
        
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
        
        self.hasBody = dictionary.keys.contains(SwiftDocKey.bodyOffset.rawValue)
    }
}

// MARK: - Convertion

extension SourceKitDeclaration {
    
    var toToken: AnyTokenBox {
        if isInjectable {
            return TokenBox(value: InjectableType(name: name), offset: offset, length: length, line: -1)
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