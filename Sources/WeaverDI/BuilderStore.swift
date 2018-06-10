//
//  BuilderStore.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

// MARK: - Storing

protocol BuilderStoring: AnyObject {
    
    func get<I, P>(for key: BuilderKey, isCalledFromAChild: Bool) -> Builder<I, P>?

    func set<I, P>(_ buidler: Builder<I, P>, for key: BuilderKey)

    var parent: BuilderStoring? { get set }
}

// MARK: - Default

extension BuilderStoring {

    func get<I, P>(for key: BuilderKey) -> Builder<I, P>? {
        return get(for: key, isCalledFromAChild: false)
    }
    
    func set<I, P>(scope: Scope, for key: BuilderKey, body: @escaping Builder<I, P>.Body) {
        set(Builder(scope: scope, body: body), for: key)
    }
}

// MARK: - Store

final class BuilderStore: BuilderStoring {
    
    private var builders: [BuilderKey: AnyBuilder] = [:]
    
    weak var parent: BuilderStoring? = nil
    
    func get<I, P>(for key: BuilderKey, isCalledFromAChild: Bool) -> Builder<I, P>? {
        
        guard let foundBuilder = builders[key] else {
            return parent?.get(for: key, isCalledFromAChild: true)
        }
    
        guard let builder = foundBuilder as? Builder<I, P> else {
            fatalError("Found a builder (\(foundBuilder.self)) with an incorrect type \(Builder<I, P>.self).")
        }
        
        if (isCalledFromAChild && builder.scope.allowsAccessFromChildren) || !isCalledFromAChild {
            return builder
        }
        
        return parent?.get(for: key, isCalledFromAChild: true)
    }
    
    func set<I, P>(_ builder: Builder<I, P>, for key: BuilderKey) {
        builders[key] = builder
    }
}
