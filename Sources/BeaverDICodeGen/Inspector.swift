//
//  Inspector.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import BeaverDI

public final class Inspector {

    private var graph = [String: Resolver]()

    private lazy var dependencies: [Dependency] = {
        return self.graph.values.flatMap { $0.dependencies.values }
    }()

    private lazy var resolutionCache = Set<Inspector.ResolutionCacheIndex>()
    private lazy var buildCache = Set<Inspector.BuildCacheIndex>()
    
    public init(syntaxTrees: [Expr]) throws {
        try buildGraph(with: syntaxTrees)
    }
    
    public func validate() throws {
        for dependency in dependencies {
            try dependency.resolve(with: &resolutionCache)
            try dependency.build(with: &buildCache)
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
        let scope: Scope?
        let associatedResolver: Resolver
        let dependentResovler: Resolver

        let line: Int
        let file: String

        init(name: String,
             scope: Scope? = nil,
             line: Int,
             file: String,
             associatedResolver: Resolver,
             dependentResovler: Resolver) {
            self.name = name
            self.scope = scope
            self.line = line
            self.file = file
            self.associatedResolver = associatedResolver
            self.dependentResovler = dependentResovler
        }
    }
    
    struct ResolutionCacheIndex {
        let resolver: Resolver
        let dependencyIndex: DependencyIndex
    }
    
    struct BuildCacheIndex {
        let resolver: Resolver
        let scope: Scope?
    }
}

// MARK: - Builders

private extension Inspector {
    
    func buildGraph(with syntaxTrees: [Expr]) throws {
        
        for ast in syntaxTrees {
            switch ast {
            case .file(let types, let name):
                try buildGraph(with: types, fileName: name)

            case .typeDeclaration,
                 .scopeAnnotation,
                 .registerAnnotation,
                 .referenceAnnotation:
                throw InspectorError.invalidAST(unexpectedExpr: ast, file: nil)
            }
        }
    }
    
    func buildGraph(with syntaxTrees: [Expr], fileName: String) throws {
        
        for ast in syntaxTrees {
            switch ast {
            case .typeDeclaration(let injectableType, let children):
                let resolver = graph.resolver(for: injectableType.value.name)
                resolver.update(with: children, fileName: fileName, store: &graph)
                
            case .file,
                 .scopeAnnotation,
                 .registerAnnotation,
                 .referenceAnnotation:
                throw InspectorError.invalidAST(unexpectedExpr: ast, file: fileName)
            }
        }
    }
}

private extension Inspector.Dependency {
    
    convenience init(dependentResolver: Inspector.Resolver,
                     registerAnnotation: TokenBox<RegisterAnnotation>,
                     scopeAnnotation: ScopeAnnotation? = nil,
                     fileName: String,
                     store: inout [String: Inspector.Resolver]) {

        let associatedResolver = store.resolver(for: registerAnnotation.value.typeName)
        
        self.init(name: registerAnnotation.value.name,
                  scope: scopeAnnotation?.scope ?? .`default`,
                  line: registerAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
    
    convenience init(dependentResolver: Inspector.Resolver,
                     referenceAnnotation: TokenBox<ReferenceAnnotation>,
                     fileName: String,
                     store: inout [String: Inspector.Resolver]) {

        let associatedResolver = store.resolver(for: referenceAnnotation.value.typeName)
        
        self.init(name: referenceAnnotation.value.name,
                  line: referenceAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
}

private extension Inspector.Resolver {
    
    func update(with children: [Expr], fileName: String, store: inout [String: Inspector.Resolver]) {

        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var referenceAnnotations: [TokenBox<ReferenceAnnotation>] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, let children):
                let resolver = store.resolver(for: injectableType.value.name)
                resolver.update(with: children, fileName: fileName, store: &store)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .referenceAnnotation(let referenceAnnotation):
                referenceAnnotations.append(referenceAnnotation)

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
                                                  fileName: fileName,
                                                  store: &store)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
        
        for referenceAnnotation in referenceAnnotations {
            let dependency = Inspector.Dependency(dependentResolver: self,
                                                  referenceAnnotation: referenceAnnotation,
                                                  fileName: fileName,
                                                  store: &store)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
    }
}

// MARK: - Resolution Check

private extension Inspector.Dependency {
    
    func resolve(with cache: inout Set<Inspector.ResolutionCacheIndex>) throws {
        guard isReference else {
            return
        }
        
        guard !dependentResovler.dependents.isEmpty else {
            throw InspectorError.invalidGraph(line: line,
                                              file: file,
                                              dependencyName: name,
                                              typeName: associatedResolver.typeName,
                                              underlyingError: .unresolvableDependency)
        }
        
        let index = Inspector.DependencyIndex(typeName: associatedResolver.typeName, name: name)
        for dependent in dependentResovler.dependents {
            do {
                try dependent.resolveDependency(index: index, cache: &cache)
            } catch let error as InspectorAnalysisError {
                throw InspectorError.invalidGraph(line: line,
                                                  file: file,
                                                  dependencyName: name,
                                                  typeName: associatedResolver.typeName,
                                                  underlyingError: error)
            }
        }
    }
}

private extension Inspector.Resolver {
    
    func resolveDependency(index: Inspector.DependencyIndex, cache: inout Set<Inspector.ResolutionCacheIndex>) throws {
        let cacheIndex = Inspector.ResolutionCacheIndex(resolver: self, dependencyIndex: index)
        guard !cache.contains(cacheIndex) else {
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
        
        if let dependency = dependencies[index], let scope = dependency.scope, scope.allowsAccessFromChildren {
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

// MARK: - Build Check

private extension Inspector.Dependency {
    
    func build(with buildCache: inout Set<Inspector.BuildCacheIndex>) throws {
        let buildCacheIndex = Inspector.BuildCacheIndex(resolver: associatedResolver, scope: scope)
        guard !buildCache.contains(buildCacheIndex) else {
            return
        }
        buildCache.insert(buildCacheIndex)
        
        guard !isReference else {
            return
        }
        
        guard let scope = scope, !scope.allowsAccessFromChildren else {
            return
        }
        
        var visitedResolvers = Set<Inspector.Resolver>()
        try associatedResolver.buildDependencies(from: self, visitedResolvers: &visitedResolvers)
    }
}

private extension Inspector.Resolver {
    
    func buildDependencies(from sourceDependency: Inspector.Dependency, visitedResolvers: inout Set<Inspector.Resolver>) throws {

        if visitedResolvers.contains(self) {
            throw InspectorError.invalidGraph(line: sourceDependency.line,
                                              file: sourceDependency.file,
                                              dependencyName: sourceDependency.name,
                                              typeName: typeName,
                                              underlyingError: .cyclicDependency)
        }
        visitedResolvers.insert(self)
        
        for dependency in dependencies.values {
            try dependency.associatedResolver.buildDependencies(from: sourceDependency, visitedResolvers: &visitedResolvers)
        }
    }
}

// MARK: - Utils

private extension Inspector.Dependency {
    
    var isReference: Bool {
        return scope == nil
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

extension Inspector.BuildCacheIndex: Hashable {
    var hashValue: Int {
        return resolver.hashValue ^ (scope?.hashValue ?? 0)
    }
    
    static func ==(lhs: Inspector.BuildCacheIndex, rhs: Inspector.BuildCacheIndex) -> Bool {
        guard lhs.resolver == rhs.resolver else { return false }
        guard lhs.scope == rhs.scope else { return false }
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
