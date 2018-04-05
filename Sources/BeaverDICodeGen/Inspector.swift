//
//  Inspector.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import BeaverDI

public final class Inspector {

    private let graph = Graph()

    private lazy var resolutionCache = Set<Inspector.ResolutionCacheIndex>()
    private lazy var buildCache = Set<Inspector.BuildCacheIndex>()
    
    public init(syntaxTrees: [Expr]) throws {
        try buildGraph(from: syntaxTrees)
    }
    
    public func validate() throws {
        for dependency in graph.dependencies {
            try dependency.resolve(with: &resolutionCache)
            try dependency.build(with: &buildCache)
        }
    }
}

private extension Inspector {
    
    final class Graph {
        private var resolversByName = [String: Resolver]()
        private var resolversByType = [String: Resolver]()
        
        lazy var dependencies: [Dependency] = {
            var allDependencies = [Dependency]()
            allDependencies.append(contentsOf: resolversByName.values.flatMap { $0.dependencies.values })
            allDependencies.append(contentsOf: resolversByType.values.flatMap { $0.dependencies.values })
 
            var filteredDependencies = Set<Dependency>()
            return allDependencies.filter {
                if filteredDependencies.contains($0) {
                    return false
                }
                filteredDependencies.insert($0)
                return true
            }
        }()
    }

    final class Resolver {
        let typeName: String?
        var dependencies: [DependencyIndex: Dependency] = [:]
        var dependents: [Resolver] = []
        
        init(typeName: String? = nil) {
            self.typeName = typeName
        }
    }
    
    struct DependencyIndex {
        let typeName: String?
        let name: String
    }
    
    final class Dependency {
        let name: String
        let scope: Scope?
        let isCustom: Bool
        let associatedResolver: Resolver
        let dependentResovler: Resolver

        let line: Int
        let file: String

        init(name: String,
             scope: Scope? = nil,
             isCustom: Bool,
             line: Int,
             file: String,
             associatedResolver: Resolver,
             dependentResovler: Resolver) {
            self.name = name
            self.scope = scope
            self.isCustom = isCustom
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

// MARK: - Graph

extension Inspector.Graph {
    
    func insertResolver(with registerAnnotation: RegisterAnnotation) {
        let resolver = Inspector.Resolver(typeName: registerAnnotation.typeName)
        resolversByName[registerAnnotation.name] = resolver
        resolversByType[registerAnnotation.typeName] = resolver
    }
    
    func insertResolver(with referenceAnnotation: ReferenceAnnotation) {
        if resolversByName[referenceAnnotation.name] != nil {
            return
        }
        resolversByName[referenceAnnotation.name] = Inspector.Resolver()
    }

    func resolver(named name: String) -> Inspector.Resolver? {
        return resolversByName[name]
    }
    
    func resolver(typed type: String) -> Inspector.Resolver {
        if let resolver = resolversByType[type] {
            return resolver
        }
        let resolver = Inspector.Resolver(typeName: type)
        resolversByType[type] = resolver
        return resolver
    }
}

// MARK: - Builders

private extension Inspector {
    
    func buildGraph(from syntaxTrees: [Expr]) throws {
        collectResolvers(from: syntaxTrees)
        try linkResolvers(from: syntaxTrees)
    }

    private func collectResolvers(from syntaxTrees: [Expr]) {

        // Insert the resolvers for which we know the type.
        for expr in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .registerAnnotation(let token):
                graph.insertResolver(with: token.value)
                
            case .file,
                 .typeDeclaration,
                 .scopeAnnotation,
                 .referenceAnnotation,
                 .customRefAnnotation:
                break
            }
        }

        // Insert the resolvers for which we don't know the type.
        for expr in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .referenceAnnotation(let token):
                graph.insertResolver(with: token.value)
                
            case .file,
                 .registerAnnotation,
                 .typeDeclaration,
                 .scopeAnnotation,
                 .customRefAnnotation:
                break
            }
        }
    }
    
    private func linkResolvers(from syntaxTrees: [Expr]) throws {
        
        for ast in syntaxTrees {
            switch ast {
            case .file(let types, let name):
                try linkResolvers(from: types, fileName: name)
                
            case .typeDeclaration,
                 .scopeAnnotation,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .customRefAnnotation:
                throw InspectorError.invalidAST(unexpectedExpr: ast, file: nil)
            }
        }
    }
    
    private func linkResolvers(from exprs: [Expr], fileName: String) throws {
        
        for expr in exprs {
            switch expr {
            case .typeDeclaration(let injectableType, let children):
                let resolver = graph.resolver(typed: injectableType.value.name)
                try resolver.update(with: children, fileName: fileName, graph: graph)
                
            case .file,
                 .scopeAnnotation,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .customRefAnnotation:
                throw InspectorError.invalidAST(unexpectedExpr: expr, file: fileName)
            }
        }
    }
}

private extension Inspector.Dependency {
    
    convenience init(dependentResolver: Inspector.Resolver,
                     registerAnnotation: TokenBox<RegisterAnnotation>,
                     scopeAnnotation: ScopeAnnotation? = nil,
                     customRefAnnotation: CustomRefAnnotation?,
                     fileName: String,
                     graph: Inspector.Graph) throws {

        guard let associatedResolver = graph.resolver(named: registerAnnotation.value.name) else {
            throw InspectorError.invalidGraph(line: registerAnnotation.line,
                                              file: fileName,
                                              dependencyName: registerAnnotation.value.name,
                                              typeName: registerAnnotation.value.typeName,
                                              underlyingError: .unresolvableDependency)
        }
        
        self.init(name: registerAnnotation.value.name,
                  scope: scopeAnnotation?.scope ?? .`default`,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue,
                  line: registerAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
    
    convenience init(dependentResolver: Inspector.Resolver,
                     referenceAnnotation: TokenBox<ReferenceAnnotation>,
                     customRefAnnotation: CustomRefAnnotation?,
                     fileName: String,
                     graph: Inspector.Graph) throws {

        guard let associatedResolver = graph.resolver(named: referenceAnnotation.value.name) else {
            throw InspectorError.invalidGraph(line: referenceAnnotation.line,
                                              file: fileName,
                                              dependencyName: referenceAnnotation.value.name,
                                              typeName: referenceAnnotation.value.typeName,
                                              underlyingError: .unresolvableDependency)
        }
        
        self.init(name: referenceAnnotation.value.name,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue,
                  line: referenceAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
}

private extension Inspector.Resolver {
    
    func update(with children: [Expr], fileName: String, graph: Inspector.Graph) throws {

        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var referenceAnnotations: [TokenBox<ReferenceAnnotation>] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        var customRefAnnotations: [String: CustomRefAnnotation] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, let children):
                let resolver = graph.resolver(typed: injectableType.value.name)
                try resolver.update(with: children, fileName: fileName, graph: graph)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .referenceAnnotation(let referenceAnnotation):
                referenceAnnotations.append(referenceAnnotation)

            case .scopeAnnotation(let scopeAnnotation):
                scopeAnnotations[scopeAnnotation.value.name] = scopeAnnotation.value
                
            case .customRefAnnotation(let customRefAnnotation):
                customRefAnnotations[customRefAnnotation.value.name] = customRefAnnotation.value
                
            case .file:
                break
            }
        }
        
        for registerAnnotation in registerAnnotations {
            let dependency = try Inspector.Dependency(dependentResolver: self,
                                                      registerAnnotation: registerAnnotation,
                                                      scopeAnnotation: scopeAnnotations[registerAnnotation.value.name],
                                                      customRefAnnotation: customRefAnnotations[registerAnnotation.value.name],
                                                      fileName: fileName,
                                                      graph: graph)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
        
        for referenceAnnotation in referenceAnnotations {
            let dependency = try Inspector.Dependency(dependentResolver: self,
                                                      referenceAnnotation: referenceAnnotation,
                                                      customRefAnnotation: customRefAnnotations[referenceAnnotation.value.name],
                                                      fileName: fileName,
                                                      graph: graph)
            let index = Inspector.DependencyIndex(typeName: dependency.associatedResolver.typeName, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
    }
}

// MARK: - Resolution Check

private extension Inspector.Dependency {
    
    func resolve(with cache: inout Set<Inspector.ResolutionCacheIndex>) throws {
        guard isReference && !isCustom else {
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
        
        if let dependency = dependencies[index], let scope = dependency.scope {
            if (dependency.isCustom && scope.allowsAccessFromChildren) || scope.allowsAccessFromChildren {
                return
            }
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
        
        guard !isReference && !isCustom else {
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
        return (typeName ?? "").hashValue ^ name.hashValue
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

