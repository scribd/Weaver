//
//  SourceKitTypeDeclaration.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

struct SourceKitTypeDeclaration: Decodable {
    
    enum Constant {
        static let supportedTypeDeclarationKinds: [SwiftDeclarationKind] = [
            .`class`,
            .`enum`,
            .`struct`
        ]
    }
    
    enum Error: String, Swift.Error {
        case unsupportedKind = "Unsupported kind"
    }
    
    let offset: Int
    let length: Int
    let name: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SwiftDocKey.self)

        let kindString = try container.decode(String.self, forKey: .kind)
        guard let kind = SwiftDeclarationKind(rawValue: kindString), Constant.supportedTypeDeclarationKinds.contains(kind) else {
            throw Error.unsupportedKind
        }
        
        offset = try container.decode(Int.self, forKey: .offset)
        length = try container.decode(Int.self, forKey: .length)
        name = try container.decode(String.self, forKey: .name)
    }
}

// MARK: - CodingKey

extension SwiftDocKey: CodingKey {
}

// MARK: - Convertion

extension SourceKitTypeDeclaration {
    
    var toToken: Token {
        return Token(type: .type, offset: offset, length: length, line: -1)
    }
}
