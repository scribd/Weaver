//
//  BuilderStore.swift
//  BeaverDI
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

/// Object responsible of storing and fetching the dependency builders
protocol BuilderStoring: AnyObject {
    
    /// Gets a builder for a key.
    /// Will attempt to get a valid builder from the parent if none is found at its own level.
    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B?

    /// Sets a builder for a key.
    func set<B>(builder: B, scope: Scope, for key: InstanceKey)

    var parent: BuilderStoring? { get set }
}

// MARK: - Convenience

extension BuilderStoring {

    func get<B>(for key: InstanceKey) -> B? {
        return get(for: key, isCalledFromAChild: false)
    }
}

// MARK: - Implementation

final class BuilderStore: BuilderStoring {
    
    private var builders: [InstanceKey: Builder] = [:]
    
    weak var parent: BuilderStoring? = nil
    
    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B? {
        
        guard let builder = builders[key], let body = builder.body as? B else {
            return parent?.get(for: key, isCalledFromAChild: true)
        }
        
        if (isCalledFromAChild && builder.scope.allowsAccessFromChildren) || !isCalledFromAChild {
            return body
        }
        
        return parent?.get(for: key, isCalledFromAChild: true)
    }
    
    func set<B>(builder: B, scope: Scope, for key: InstanceKey) {
        builders[key] = Builder(scope: scope, body: builder)
    }
}

// MARK: - Instance Builder

private extension BuilderStore {
    
    final class Builder {
        
        let scope: Scope
        let body: Any
        
        init(scope: Scope, body: Any) {
            self.scope = scope
            self.body = body
        }
    }
}
