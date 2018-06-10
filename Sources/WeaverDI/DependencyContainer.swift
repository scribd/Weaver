//
//  DependencyContainer.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

open class DependencyContainer {
    
    private let builders: BuilderStoring
    
    private let parent: DependencyContainer?
    
    lazy var dependencies = InternalDependencyStore(builders)
    
    init(parent: DependencyContainer? = nil,
         builders: BuilderStoring = BuilderStore()) {
        self.parent = parent
        
        builders.parent = parent?.builders
        self.builders = builders
        
        registerDependencies(in: dependencies)
    }
    
    public init(_ parent: DependencyContainer? = nil) {
        self.parent = parent
        builders = BuilderStore()
        builders.parent = parent?.builders

        registerDependencies(in: dependencies)
    }
    
    open func registerDependencies(in store: DependencyStore) {
        // No-op
    }
}

// MARK: - DependencyResolver

extension DependencyContainer: DependencyResolver {
    
    public func resolve<S>(_ serviceType: S.Type, name: String? = nil) -> S {
        let key = BuilderKey(for: serviceType, name: name)

        guard let builder: Builder<S, DependencyContainer> = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder.make()({ self })
    }
    
    public func resolve<S, P1>(_ serviceType: S.Type, name: String? = nil, parameter: P1) -> S {
        let key = BuilderKey(for: serviceType, name: name, parameterType: P1.self)
        
        guard let builder: Builder<S, (DependencyContainer, P1)> = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder.make()({ (self, parameter) })
    }
    
    public func resolve<S, P1, P2>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2) -> S {
        let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self)
        
        guard let builder: Builder<S, (DependencyContainer, P1, P2)> = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder.make()({ (self, p1, p2) })
    }
    
    public func resolve<S, P1, P2, P3>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2, _ p3: P3) -> S {
        let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self)
        
        guard let builder: Builder<S, (DependencyContainer, P1, P2, P3)> = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder.make()({ (self, p1, p2, p3) })
    }
    
    public func resolve<S, P1, P2, P3, P4>(_ serviceType: S.Type, name: String? = nil, parameters p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) -> S {
        let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self, P4.self)
        
        guard let builder: Builder<S, (DependencyContainer, P1, P2, P3, P4)> = builders.get(for: key) else {
            fatalError("\(DependencyContainer.self): Could not resolve \(key).")
        }
        
        return builder.make()({ (self, p1, p2, p3, p4) })
    }
}

// MARK: - DependencyStore

extension DependencyContainer {

    final class InternalDependencyStore: DependencyStore {
        
        private let builders: BuilderStoring
        
        init(_ builders: BuilderStoring) {
            self.builders = builders
        }

        public func register<S>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer) -> S) {
            let key = BuilderKey(for: serviceType, name: name)
            
            builders.set(scope: scope, for: key) { (parameter: () -> (DependencyContainer)) -> S in
                return builder(parameter())
            }
        }
        
        public func register<S, P1>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1) -> S) {
            let key = BuilderKey(for: serviceType, name: name, parameterType: P1.self)
            
            builders.set(scope: scope, for: key) { (parameters: () -> (DependencyContainer, P1)) -> S in
                return builder(parameters().0, parameters().1)
            }
        }
        
        public func register<S, P1, P2>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2) -> S) {
            let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self)
            
            builders.set(scope: scope, for: key) { (parameters: () -> (DependencyContainer, P1, P2)) -> S in
                return builder(parameters().0, parameters().1, parameters().2)
            }
        }
        
        public func register<S, P1, P2, P3>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2, P3) -> S) {
            let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self)
            
            builders.set(scope: scope, for: key) { (parameters: () -> (DependencyContainer, P1, P2, P3)) -> S in
                return builder(parameters().0, parameters().1, parameters().2, parameters().3)
            }
        }
        
        public func register<S, P1, P2, P3, P4>(_ serviceType: S.Type, scope: Scope, name: String? = nil, builder: @escaping (DependencyContainer, P1, P2, P3, P4) -> S) {
            let key = BuilderKey(for: serviceType, name: name, parameterTypes: P1.self, P2.self, P3.self, P4.self)
            
            builders.set(scope: scope, for: key) { (parameters: () -> (DependencyContainer, P1, P2, P3, P4)) -> S in
                return builder(parameters().0, parameters().1, parameters().2, parameters().3, parameters().4)
            }
        }
    }
}
