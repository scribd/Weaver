//
//  Arguments.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import Commander
import PathKit

extension Optional: ArgumentConvertible, CustomStringConvertible where Wrapped: ArgumentConvertible {

    public init(parser: ArgumentParser) throws {
        self = try? Wrapped(parser: parser)
    }
    
    public var description: String {
        // Do not change this implementation since this description override
        // also has an impact on Stencil's reflexion system.
        switch self {
        case .none:
            return "nil"
        case .some(let value):
            return value.description
        }
    }
}

extension Path: ArgumentConvertible {
    public init(parser: ArgumentParser) throws {
        guard let value = parser.shift() else {
            throw ArgumentError.missingValue(argument: nil)
        }
        self.init(value)
    }
}

struct OptionalFlag: ArgumentDescriptor {
    typealias ValueType = Bool?
    
    let name: String
    let `default`: ValueType
    let flag: Character?
    let disabledName: String
    let disabledFlag: Character?
    let description: String?
    var type: ArgumentType { return .option }
    
    init(_ name: String, default: Bool? = nil, flag: Character? = nil, disabledName: String? = nil, disabledFlag: Character? = nil, description: String? = nil) {
        self.name = name
        self.`default` = `default`
        self.disabledName = disabledName ?? "no-\(name)"
        self.flag = flag
        self.disabledFlag = disabledFlag
        self.description = description
    }
    
    func parse(_ parser: ArgumentParser) throws -> ValueType {
        if parser.hasOption(disabledName) {
            return false
        }
        
        if parser.hasOption(name) {
            return true
        }
        
        if let flag = flag {
            if parser.hasFlag(flag) {
                return true
            }
        }
        if let disabledFlag = disabledFlag {
            if parser.hasFlag(disabledFlag) {
                return false
            }
        }
        
        return `default`
    }
}
