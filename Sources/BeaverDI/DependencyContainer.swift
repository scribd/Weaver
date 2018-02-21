//
//  DependencyContainer.swift
//  BeaverDIPackageDescription
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

final class DependencyContainer {
    
    private var builders: [InstanceKey: Any] = [:]
    
    private let instances: InstanceCaching
    
    init(instanceCache: InstanceCaching = InstanceCache()) {
        instances = instanceCache
    }
}

// MARK: - DependencyResolver

extension DependencyContainer: DependencyResolver {
    
    func resolve<S>(_ serviceType: S.Type) -> S {
        let key = InstanceKey(for: serviceType)
        
        guard let builder = builders[key] as? (DependencyContainer) -> S else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder(self)
    }
    
    func resolve<S, P1>(_ serviceType: S.Type, parameter: P1) -> S {
        let key = InstanceKey(for: serviceType, parameterType: P1.self)
        
        guard let builder = builders[key] as? (DependencyContainer, P1) -> S else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, parameter)
    }
    
    func resolve<S, P1, P2>(_ serviceType: S.Type, parameters p1: P1, _ p2: P2) -> S {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self)
        
        guard let builder = builders[key] as? (DependencyContainer, P1, P2) -> S else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2)
    }
    
    func resolve<S, P1, P2, P3>(_ serviceType: S.Type, parameters p1: P1, _ p2: P2, _ p3: P3) -> S {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self, P3.self)
        
        guard let builder = builders[key] as? (DependencyContainer, P1, P2, P3) -> S else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2, p3)
    }
    
    func resolve<S, P1, P2, P3, P4>(_ serviceType: S.Type, parameters p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) -> S {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self, P3.self, P4.self)
        
        guard let builder = builders[key] as? (DependencyContainer, P1, P2, P3, P4) -> S else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key)")
        }
        
        return builder(self, p1, p2, p3, p4)
    }
}

// MARK: - DependencyStore

extension DependencyContainer: DependencyStore {
    
    func register<S>(_ serviceType: S.Type, scope: Scope, builder: @escaping (DependencyResolver) -> S) {
        let key = InstanceKey(for: serviceType)

        let builderWrapper: (DependencyContainer) -> S = { strongSelf in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf) }
        }
        
        builders[key] = builderWrapper
    }
    
    func register<S, P1>(_ serviceType: S.Type, scope: Scope, builder: @escaping (DependencyResolver, P1) -> S) {
        let key = InstanceKey(for: serviceType, parameterType: P1.self)

        let builderWrapper: (DependencyContainer, P1) -> S = { strongSelf, parameter in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, parameter) }
        }
        
        builders[key] = builderWrapper
    }
    
    func register<S, P1, P2>(_ serviceType: S.Type, scope: Scope, builder: @escaping (DependencyResolver, P1, P2) -> S) {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self)

        let builderWrapper: (DependencyContainer, P1, P2) -> S = { strongSelf, p1, p2 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2) }
        }
        
        builders[key] = builderWrapper
    }
    
    func register<S, P1, P2, P3>(_ serviceType: S.Type, scope: Scope, builder: @escaping (DependencyResolver, P1, P2, P3) -> S) {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self, P3.self)

        let builderWrapper: (DependencyContainer, P1, P2, P3) -> S = { strongSelf, p1, p2, p3 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2, p3) }
        }
        
        builders[key] = builderWrapper
    }
    
    func register<S, P1, P2, P3, P4>(_ serviceType: S.Type, scope: Scope, builder: @escaping (DependencyResolver, P1, P2, P3, P4) -> S) {
        let key = InstanceKey(for: serviceType, parameterTypes: P1.self, P2.self, P3.self, P4.self)

        let builderWrapper: (DependencyContainer, P1, P2, P3, P4) -> S = { strongSelf, p1, p2, p3, p4 in
            return strongSelf.instances.cache(for: key, scope: scope) { builder(strongSelf, p1, p2, p3, p4) }
        }
        
        builders[key] = builderWrapper
    }
}


