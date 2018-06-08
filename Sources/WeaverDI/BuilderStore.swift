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

// MARK: - Builder

final class Builder {

    let scope: Scope
    private let body: Any
    private var instance: Instance?
    
    init(scope: Scope, body: Any) {
        self.scope = scope
        self.body = body
    }
    
    func functor<P, I>() -> (() -> P) -> I {
        
        guard let body = body as? (() -> P) -> I else {
            fatalError("Type \(((() -> P) -> I).self) doesn't correspond to body type: \(self.body.self)")
        }
        
        guard !scope.isTransient else {
            return body
        }
        
        return { (parameters: () -> P) -> I in
            if let instance = self.instance?.value as? I {
                return instance
            }
            
            let instance = body(parameters)
            self.instance = Instance(value: instance as AnyObject, scope: self.scope)
            return instance
        }
    }
}

// MARK: - Instance

private final class Instance {
    private weak var weakValue: AnyObject?
    private var strongValue: AnyObject?
    
    init(value: AnyObject, scope: Scope) {

        if scope.isWeak {
            weakValue = value
        } else {
            strongValue = value
        }
    }
    
    var value: AnyObject? {
        return weakValue ?? strongValue ?? nil
    }
}
