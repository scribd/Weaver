//
//  BuilderStore.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

// MARK: - Storing

protocol BuilderStoring: AnyObject {
    
    func get(for key: InstanceKey, isCalledFromAChild: Bool) -> Builder?

    func set<P, I>(scope: Scope, key: InstanceKey, builder: @escaping (() -> P) -> I)

    var parent: BuilderStoring? { get set }
}

// MARK: - Default

extension BuilderStoring {

    func get(for key: InstanceKey) -> Builder? {
        return get(for: key, isCalledFromAChild: false)
    }
}

// MARK: - Store

final class BuilderStore: BuilderStoring {
    
    private var builders: [InstanceKey: Builder] = [:]
    
    weak var parent: BuilderStoring? = nil
    
    func get(for key: InstanceKey, isCalledFromAChild: Bool) -> Builder? {
        
        guard let builder = builders[key] else {
            return parent?.get(for: key, isCalledFromAChild: true)
        }
        
        if (isCalledFromAChild && builder.scope.allowsAccessFromChildren) || !isCalledFromAChild {
            return builder
        }
        
        return parent?.get(for: key, isCalledFromAChild: true)
    }
    
    func set<P, I>(scope: Scope, key: InstanceKey, builder: @escaping (() -> P) -> I) {
        builders[key] = Builder(scope: scope, body: builder)
    }
}
