//
//  ConfigurationAttribute.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 5/13/18.
//

import Foundation

enum ConfigurationAttribute {
    case isIsolated(value: Bool)
}

// MARK: - Equatable

extension ConfigurationAttribute: Equatable {

    static func ==(lhs: ConfigurationAttribute, rhs: ConfigurationAttribute) -> Bool {
        switch (lhs, rhs) {
        case (.isIsolated(let lhs), .isIsolated(let rhs)):
            return lhs == rhs
        }
    }
}

// MARK: - Hashable

extension ConfigurationAttribute: Hashable {

    var hashValue: Int {
        switch self {
        case .isIsolated(let value):
            return description.hashValue ^ value.hashValue
        }
    }
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
