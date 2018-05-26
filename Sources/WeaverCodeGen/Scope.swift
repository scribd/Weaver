//
//  Scope.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/14/18.
//

import Foundation
import WeaverDI

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
