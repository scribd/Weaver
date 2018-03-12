//
//  Inspector.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation

final class Inspector {
    
    private var graph = [String: Resolver]()

    private lazy var dependencies: [Dependency] = {
        return self.graph.values.flatMap { $0.dependencies.values }
    }()

    private lazy var resolutionCache: [Inspector.CanResolverDependencyIndex: Bool] = [:]
    
    public init(syntaxTrees: [Expr]) throws {
        try buildGraph(with: syntaxTrees)
    }
    
    public var isValid: Bool {
        for dependency in dependencies where !dependency.isResolvable(cache: &resolutionCache) {
            return false
        }
        return true
    }
}

private extension Inspector {
    final class Resolver {
        
        let typeName: String
        var dependencies: [DependencyIndex: Dependency] = [:]
        var dependents: [Resolver] = []
        
        init(typeName: String) {
            self.typeName = typeName
        }
    }
    
    struct DependencyIndex {
        let typeName: String
        let name: String
    }
    
    final class Dependency {
        
        let name: String
        let scope: ScopeAnnotation.ScopeType
        let associatedResolver: Resolver
        let dependentResovler: Resolver
        
        init(name: String,
             scope: ScopeAnnotation.ScopeType,
             associatedResolver: Resolver,
             dependentResovler: Resolver) {
            self.name = name
            self.scope = scope
            self.associatedResolver = associatedResolver
            self.dependentResovler = dependentResovler
        }
    }
    
    struct CanResolverDependencyIndex {
        let resolver: Resolver
        let dependencyIndex: DependencyIndex
    }
}

// MARK: - Builders

private extension Inspector {
    
    func buildGraph(with syntaxTrees: [Expr]) throws {
        
        for ast in syntaxTrees {
            switch ast {
            case .file(let types):
                try buildGraph(with: types)
                
            case .typeDeclaration(let injectableType, _, let children):
                let resolver = graph.resolver(for: injectableType.value.name)
                resolver.update(with: children, store: &graph)

            case .scopeAnnotation,
                 .registerAnnotation:
                throw InspectorError.invalidAST(unexpectedExpr: ast)
            }
        }
    }
}

private extension Inspector.Dependency {
    
    convenience init(dependentResolver: Inspector.Resolver,
                     registerAnnotation: RegisterAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     store: inout [String: Inspector.Resolver]) {

        let associatedResolver = store.resolver(for: registerAnnotation.typeName)
        
        self.init(name: registerAnnotation.name,
                  scope: scopeAnnotation?.scope ?? .`default`,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
}

private extension Inspector.Resolver {
    
    func update(with children: [Expr], store: inout [String: Inspector.Resolver]) {

        var registerAnnotations: [RegisterAnnotation] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, _, let children):
                let resolver = store.resolver(for: injectableType.value.name)
                resolver.update(with: children, store: &store)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation.value)
                
            case .scopeAnnotation(let scopeAnnotation):
                scopeAnnotations[scopeAnnotation.value.name] = scopeAnnotation.value
                
            case .file:
                break
            }
        }
        
        for registerAnnotation in registerAnnotations {
            let dependency = Inspector.Dependency(dependentResolver: self,
                                                  registerAnnotation: registerAnnotation,
                                                  scopeAnnotation: scopeAnnotations[registerAnnotation.name],
                                                  store: &store)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
    }
}

// MARK: - Resolver Checks

private extension Inspector.Dependency {
    
    func isResolvable(cache: inout [Inspector.CanResolverDependencyIndex: Bool]) -> Bool {
        if scope != .parent {
            return true
        }
        
        let index = Inspector.DependencyIndex(typeName: associatedResolver.typeName, name: name)
        for dependent in dependentResovler.dependents {
            guard dependent.canResolveDependency(index: index, cache: &cache) else {
                return false
            }
        }
        
        return true
    }
}

private extension Inspector.Resolver {
    
    func canResolveDependency(index: Inspector.DependencyIndex, cache: inout [Inspector.CanResolverDependencyIndex: Bool]) -> Bool {
        let cacheIndex = Inspector.CanResolverDependencyIndex(resolver: self, dependencyIndex: index)
        if let result = cache[cacheIndex] {
            return result
        }
        var visitedResolvers = Set<Inspector.Resolver>()
        let result = canResolveDependency(index: index, visitedResolvers: &visitedResolvers)
        cache[cacheIndex] = result
        return result
    }
    
    private func canResolveDependency(index: Inspector.DependencyIndex, visitedResolvers: inout Set<Inspector.Resolver>) -> Bool {
        if visitedResolvers.contains(self) {
            return false
        }
        visitedResolvers.insert(self)
        
        if let dependency = dependencies[index], dependency.scope.allowsAccessFromChildren {
            return true
        }
        
        for dependent in dependents where dependent.canResolveDependency(index: index, visitedResolvers: &visitedResolvers) {
            return true
        }
        
        return false
    }
}

private extension ScopeAnnotation.ScopeType {

    var allowsAccessFromChildren: Bool {
        switch self {
        case .weak,
             .container:
            return true
        case .transient,
             .graph,
             .parent:
            return false
        }
    }
}

// MARK: - Hashable

extension Inspector.Resolver: Hashable {
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Inspector.Resolver, rhs: Inspector.Resolver) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Inspector.Dependency: Hashable {

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Inspector.Dependency, rhs: Inspector.Dependency) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Inspector.DependencyIndex: Hashable {
    
    var hashValue: Int {
        return typeName.hashValue ^ name.hashValue
    }
    
    static func ==(lhs: Inspector.DependencyIndex, rhs: Inspector.DependencyIndex) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.typeName == rhs.typeName else { return false }
        return true
    }
}

extension Inspector.CanResolverDependencyIndex: Hashable {

    var hashValue: Int {
        return resolver.hashValue ^ dependencyIndex.hashValue
    }
    
    static func ==(lhs: Inspector.CanResolverDependencyIndex, rhs: Inspector.CanResolverDependencyIndex) -> Bool {
        guard lhs.resolver == rhs.resolver else { return false }
        guard lhs.dependencyIndex == rhs.dependencyIndex else { return false }
        return true
    }
}

// MARK: - Collection Builder

private extension Dictionary where Key == String, Value == Inspector.Resolver {
    
    mutating func resolver(for typeName: String) -> Inspector.Resolver {
        if let resolver = self[typeName] {
            return resolver
        }
        let resolver = Inspector.Resolver(typeName: typeName)
        self[typeName] = resolver
        return resolver
    }
}
