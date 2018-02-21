//
//  Scope.swift
//  BeaverDIPackageDescription
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Enum representing the scope of an instance.
///
/// Possible cases:
/// - transient: the store always creates a new instance when the type is resolved.
/// - graph: a new instance is created when resolved the first time and then lives for the time the store object lives.
/// - weak: a new instance is created when resolved the first time and then lives for the time its strong references are living.
public enum Scope {
    case transient
    case weak
    case graph
}

// MARK: Rules

extension Scope {
    
    var isWeak: Bool {
        switch self {
        case .weak:
            return true
        case .transient,
             .graph:
            return false
        }
    }
    
    var isTransient: Bool {
        switch self {
        case .transient:
            return true
        case .graph,
             .weak:
            return false
        }
    }
}
