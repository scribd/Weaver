//
//  ConfigurationAttribute.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 5/13/18.
//

import Foundation

enum ConfigurationAttribute: AutoEquatable, AutoHashable {
    case isIsolated(value: Bool)
}

// MARK: - Description

extension ConfigurationAttribute: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .isIsolated(let value):
            return "Config Attr - self.isIsolated = \(value)"
        }
    }
    
    var name: String {
        switch self {
        case .isIsolated:
            return "isIsolated"
        }
    }
}
