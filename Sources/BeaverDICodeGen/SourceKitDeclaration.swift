//
//  SourceKitTypeDeclaration.swift
//  BeaverDICodeGen
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
    
    var toToken: Token {
        return Token(type: isInjectable ? .injectableType : .anyDeclaration,
                     offset: offset,
                     length: length,
                     line: -1)
    }
    
    var endToken: Token? {
        guard hasBody == true else {
            return nil
        }
        return Token(type: isInjectable ? .endOfInjectableType : .endOfAnyDeclaration,
                     offset: offset + length - 1,
                     length: 1,
                     line: -1)
    }
}
