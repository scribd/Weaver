//
//  BuilderKey.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

struct BuilderKey: CustomStringConvertible {
    
    let description: String
    
    init<S>(for serviceType: S.Type, name: String?) {
        description = "\(name ?? "_"):\(S.self)"
    }

    init<S, P1>(for serviceType: S.Type, name: String?, parameterType: P1.Type) {
        description = "\(name ?? "_"):\(S.self)(\(P1.self))"
    }
    
    init<S, P1, P2>(for serviceType: S.Type, name: String?, parameterTypes p1: P1.Type, _ p2: P2.Type) {
        description = "\(name ?? "_"):\(S.self)(\(P1.self),\(P2.self))"
    }
    
    init<S, P1, P2, P3>(for serviceType: S.Type, name: String?, parameterTypes p1: P1.Type, _ p2: P2.Type, _ p3: P3.Type) {
        description = "\(name ?? "_"):\(S.self)(\(P1.self),\(P2.self),\(P3.self))"
    }
    
    init<S, P1, P2, P3, P4>(for serviceType: S.Type, name: String?, parameterTypes p1: P1.Type, _ p2: P2.Type, _ p3: P3.Type, _ p4: P4.Type) {
        description = "\(name ?? "_"):\(S.self)(\(P1.self),\(P2.self),\(P3.self),\(P4.self))"
    }
}

// MARK: - Hashable

extension BuilderKey: Hashable {

    var hashValue: Int {
        return description.hashValue
    }
    
    static func ==(lhs: BuilderKey, rhs: BuilderKey) -> Bool {
        return lhs.description == rhs.description
    }
}
