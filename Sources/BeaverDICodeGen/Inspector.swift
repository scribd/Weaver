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

    private lazy var resolutionCache = Set<Inspector.ResolutionCacheIndex>()
    
    public init(syntaxTrees: [Expr]) throws {
        try buildGraph(with: syntaxTrees)
    }
    
    public func validate() throws {
        for dependency in dependencies {
            try dependency.isResolvable(cache: &resolutionCache)
        }
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
        let line: Int
        let associatedResolver: Resolver
        let dependentResovler: Resolver
        
        init(name: String,
             scope: ScopeAnnotation.ScopeType,
             line: Int,
             associatedResolver: Resolver,
             dependentResovler: Resolver) {
            self.name = name
            self.scope = scope
            self.line = line
            self.associatedResolver = associatedResolver
            self.dependentResovler = dependentResovler
        }
    }
    
    struct ResolutionCacheIndex {
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
                     registerAnnotation: TokenBox<RegisterAnnotation>,
                     scopeAnnotation: ScopeAnnotation?,
                     store: inout [String: Inspector.Resolver]) {

        let associatedResolver = store.resolver(for: registerAnnotation.value.typeName)
        
        self.init(name: registerAnnotation.value.name,
                  scope: scopeAnnotation?.scope ?? .`default`,
                  line: registerAnnotation.line,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
}

private extension Inspector.Resolver {
    
    func update(with children: [Expr], store: inout [String: Inspector.Resolver]) {

        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, _, let children):
                let resolver = store.resolver(for: injectableType.value.name)
                resolver.update(with: children, store: &store)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .scopeAnnotation(let scopeAnnotation):
                scopeAnnotations[scopeAnnotation.value.name] = scopeAnnotation.value
                
            case .file:
                break
            }
        }
        
        for registerAnnotation in registerAnnotations {
            let dependency = Inspector.Dependency(dependentResolver: self,
                                                  registerAnnotation: registerAnnotation,
                                                  scopeAnnotation: scopeAnnotations[registerAnnotation.value.name],
                                                  store: &store)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
    }
}

// MARK: - Resolver Checks

private extension Inspector.Dependency {
    
    func isResolvable(cache: inout Set<Inspector.ResolutionCacheIndex>) throws {
        if scope != .parent {
            return
        }
        
        guard !dependentResovler.dependents.isEmpty else {
            throw InspectorError.invalidGraph(line: line,
                                              dependencyName: name,
                                              typeName: associatedResolver.typeName,
                                              underlyingIssue: .unresolvableDependency)
        }
        
        let index = Inspector.DependencyIndex(typeName: associatedResolver.typeName, name: name)
        for dependent in dependentResovler.dependents {
            do {
                try dependent.resolveDependency(index: index, cache: &cache)
            } catch let error as InspectorAnalysisError {
                throw InspectorError.invalidGraph(line: line,
                                                  dependencyName: name,
                                                  typeName: associatedResolver.typeName,
                                                  underlyingIssue: error)
            }
        }
    }
}

private extension Inspector.Resolver {
    
    func resolveDependency(index: Inspector.DependencyIndex, cache: inout Set<Inspector.ResolutionCacheIndex>) throws {
        let cacheIndex = Inspector.ResolutionCacheIndex(resolver: self, dependencyIndex: index)
        if cache.contains(cacheIndex) {
            return
        }

        var visitedResolvers = Set<Inspector.Resolver>()
        try resolveDependency(index: index, visitedResolvers: &visitedResolvers)
        
        cache.insert(cacheIndex)
    }
    
    private func resolveDependency(index: Inspector.DependencyIndex, visitedResolvers: inout Set<Inspector.Resolver>) throws {
        if visitedResolvers.contains(self) {
            throw InspectorAnalysisError.cyclicDependency
        }
        visitedResolvers.insert(self)
        
        if let dependency = dependencies[index], dependency.scope.allowsAccessFromChildren {
            return
        }
        
        for dependent in dependents {
            if let _ = try? dependent.resolveDependency(index: index, visitedResolvers: &visitedResolvers) {
                return
            }
        }
        
        throw InspectorAnalysisError.unresolvableDependency
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

extension Inspector.ResolutionCacheIndex: Hashable {

    var hashValue: Int {
        return resolver.hashValue ^ dependencyIndex.hashValue
    }
    
    static func ==(lhs: Inspector.ResolutionCacheIndex, rhs: Inspector.ResolutionCacheIndex) -> Bool {
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
