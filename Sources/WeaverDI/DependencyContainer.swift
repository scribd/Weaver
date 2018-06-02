//
//  DependencyContainer.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

open class DependencyContainer {
    
    private var builders: BuilderStoring
    
    private let instances: InstanceCaching
    
    private let parent: DependencyContainer?
    
    init(parent: DependencyContainer? = nil,
         builderStore: BuilderStoring = BuilderStore(),
         instanceCache: InstanceCaching = InstanceCache()) {
        self.parent = parent
        instances = ThreadSafeInstanceCachingDecorator(cache: instanceCache)
        builders = ThreadSafeBuilderStoreDecorator(builders: builderStore)
        builders.parent = parent?.builders
        
        registerDependencies(in: self)
    }
    
    public convenience init(_ parent:  DependencyContainer? = nil) {
        self.init(parent: parent)
    }
    
    open func registerDependencies(in store: DependencyStore) {
        // No-op
    }
}

// MARK: - DependencyResolver

extension DependencyContainer: DependencyResolver {
    
    public func resolve<S>(_ serviceType: S.Type, name: String? = nil) -> S {
        let key = InstanceKey(for: serviceType, name: name)

        guard let builder: (DependencyContainer) -> S = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder(self)
    }
    
    public func resolve<S, P1>(_ serviceType: S.Type, name: String? = nil, parameter: P1) -> S {
        let key = InstanceKey(for: serviceType, name: name, parameterType: P1.self)
        
        guard let builder: (DependencyContainer, P1) -> S = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, parameter)
    }
    
    public func resolve<S, P1, P2>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2) -> S {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self)
        
        guard let builder: (DependencyContainer, P1, P2) -> S = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2)
    }
    
    public func resolve<S, P1, P2, P3>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2, _ p3: P3) -> S {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self)
        
        guard let builder: (DependencyContainer, P1, P2, P3) -> S = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2, p3)
    }
    
    public func resolve<S, P1, P2, P3, P4>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) -> S {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self, P4.self)
        
        guard let builder: (DependencyContainer, P1, P2, P3, P4) -> S = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2, p3, p4)
    }
}

// MARK: - DependencyStore

extension DependencyContainer: DependencyStore {
    
    public func register<S>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer) -> S) {
        let key = InstanceKey(for: serviceType, name: name)

        let builderWrapper: (DependencyContainer) -> S = { strongSelf in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf) }
        }

        builders.set(builder: builderWrapper, scope: scope, for: key)
    }
    
    public func register<S, P1>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1) -> S) {
        let key = InstanceKey(for: serviceType, name: name, parameterType: P1.self)

        let builderWrapper: (DependencyContainer, P1) -> S = { strongSelf, parameter in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, parameter) }
        }
        
        builders.set(builder: builderWrapper, scope: scope, for: key)
    }
    
    public func register<S, P1, P2>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2) -> S) {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self)

        let builderWrapper: (DependencyContainer, P1, P2) -> S = { strongSelf, p1, p2 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2) }
        }
        
        builders.set(builder: builderWrapper, scope: scope, for: key)
    }
    
    public func register<S, P1, P2, P3>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2, P3) -> S) {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self)

        let builderWrapper: (DependencyContainer, P1, P2, P3) -> S = { strongSelf, p1, p2, p3 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2, p3) }
        }
        
        builders.set(builder: builderWrapper, scope: scope, for: key)
    }
    
    public func register<S, P1, P2, P3, P4>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2, P3, P4) -> S) {
        let key = InstanceKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self, P4.self)

        let builderWrapper: (DependencyContainer, P1, P2, P3, P4) -> S = { strongSelf, p1, p2, p3, p4 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2, p3, p4) }
        }
        
        builders.set(builder: builderWrapper, scope: scope, for: key)
    }
}
