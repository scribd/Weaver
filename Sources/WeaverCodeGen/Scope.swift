//
//  Scope.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Enum representing the scope of an instance.
///
/// Possible cases:
/// - transient: the `DependencyContainer` always creates a new instance when the type is resolved.
/// - graph: a new instance is created when resolved the first time and then lives for the time the `DependencyContainer` object lives.
/// - weak: a new instance is created when resolved the first time and then lives for the time its strong references are living and shared with children.
/// - container: like graph, but shared with children.
enum Scope: String {
    case transient
    case graph
    case weak
    case container
    
    static var `default`: Scope {
        return .graph
    }
}

// MARK: Rules

extension Scope: CaseIterable, Encodable {
    
    var allowsAccessFromChildren: Bool {
        switch self {
        case .weak,
             .container:
            return true
        case .transient,
             .graph:
            return false
        }
    }
}
