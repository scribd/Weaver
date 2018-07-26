//
//  Scope.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Enum representing the scope of an instance.
///
/// Possible cases:
/// - transient: the store always creates a new instance when the type is resolved.
/// - graph: a new instance is created when resolved the first time and then lives for the time the store object lives.
/// - weak: a new instance is created when resolved the first time and then lives for the time its strong references are living and shared with children.
/// - container: like graph, but shared with children.
enum Scope {
    case transient
    case graph
    case weak
    case container
    
    static var `default`: Scope {
        return .graph
    }
}

// MARK: Rules

extension Scope {
    
    var isWeak: Bool {
        switch self {
        case .weak:
            return true
        case .transient,
             .graph,
             .container:
            return false
        }
    }
    
    var isTransient: Bool {
        switch self {
        case .transient:
            return true
        case .graph,
             .weak,
             .container:
            return false
        }
    }
    
    public var allowsAccessFromChildren: Bool {
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

// MARK: - Conversion
extension Scope {
    
    init?(_ string: String) {
        switch string {
        case Scope.transient.stringValue:
            self = .transient
        case Scope.graph.stringValue:
            self = .graph
        case Scope.weak.stringValue:
            self = .weak
        case Scope.container.stringValue:
            self = .container
        default:
            return nil
        }
    }
    
    var stringValue: String {
        switch self {
        case .transient:
            return "transient"
        case .graph:
            return "graph"
        case .weak:
            return "weak"
        case .container:
            return "container"
        }
    }
}
