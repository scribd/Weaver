//
//  Inspector.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import WeaverDI

// MARK: - Inspector

public final class Inspector {

    private let graph = Graph()

    private lazy var resolutionCache = Set<ResolutionCacheIndex>()
    private lazy var buildCache = Set<BuildCacheIndex>()
    
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

// MARK: - Graph Objects

private final class Graph {
    private var resolversByName = OrderedDictionary<String, Resolver>()
    private var resolversByType = OrderedDictionary<String, Resolver>()
    
    lazy var dependencies: [Dependency] = {
        var allDependencies = [Dependency]()
        
        allDependencies.append(contentsOf: resolversByName.orderedValues.flatMap { $0.dependencies.orderedValues })
        allDependencies.append(contentsOf: resolversByType.orderedValues.flatMap { $0.dependencies.orderedValues })

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

private final class Resolver {
    let type: Type?
    var config: ResolverConfiguration
    var accessLevel: AccessLevel
    var dependencies = OrderedDictionary<DependencyIndex, Dependency>()
    var dependents: [Resolver] = []
    var referredTypes: Set<Type>

    var fileLocation: FileLocation

    init(config: ResolverConfiguration = .empty,
         accessLevel: AccessLevel = .default,
         type: Type? = nil,
         referredType: Type? = nil,
         file: String? = nil,
         line: Int? = nil) {
        self.config = config
        self.accessLevel = accessLevel
        self.type = type

        referredTypes = Set([referredType].compactMap { $0 })
        
        fileLocation = FileLocation(line: line, file: file)
    }
}

private struct DependencyIndex {
    let type: Type?
    let name: String
}

private final class Dependency {
    let name: String
    let scope: Scope?
    let associatedResolver: Resolver
    let dependentResovler: Resolver
    var config: DependencyConfiguration

    let fileLocation: FileLocation

    init(name: String,
         scope: Scope? = nil,
         config: DependencyConfiguration = .empty,
         line: Int,
         file: String,
         associatedResolver: Resolver,
         dependentResovler: Resolver) {
        self.name = name
        self.scope = scope
        self.config = config
        self.associatedResolver = associatedResolver
        self.dependentResovler = dependentResovler

        fileLocation = FileLocation(line: line, file: file)
    }
}

private struct ResolutionCacheIndex {
    let resolver: Resolver
    let dependencyIndex: DependencyIndex
}

private struct BuildCacheIndex {
    let resolver: Resolver
    let scope: Scope?
}

// MARK: - Graph

extension Graph {
    
    func insertResolver(with registerAnnotation: TokenBox<RegisterAnnotation>,
                        fileName: String?) {
        
        let resolver = Resolver(type: registerAnnotation.value.type,
                                file: fileName,
                                line: registerAnnotation.line)
        resolversByName[registerAnnotation.value.name] = resolver
        let type = registerAnnotation.value.type
        resolversByType[type.indexKey] = resolver
    }
    
    func insertResolver(with referenceAnnotation: ReferenceAnnotation) {
        if let resolver = resolversByName[referenceAnnotation.name] {
            resolver.referredTypes.insert(referenceAnnotation.type)
            return
        }
        resolversByName[referenceAnnotation.name] = Resolver(referredType: referenceAnnotation.type)
    }

    func resolver(named name: String) -> Resolver? {
        return resolversByName[name]
    }
    
    func resolver(typed type: Type,
                  accessLevel: AccessLevel,
                  line: Int,
                  fileName: String) -> Resolver {

        if let resolver = resolversByType[type.indexKey] {
            resolver.fileLocation = FileLocation(line: line, file: fileName)
            resolver.accessLevel = accessLevel
            return resolver
        }

        let resolver = Resolver(accessLevel: accessLevel, type: type, file: fileName, line: line)
        resolversByType[type.indexKey] = resolver
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

        var fileName: String?
        
        // Insert the resolvers for which we know the type.
        for expr in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .registerAnnotation(let token):
                graph.insertResolver(with: token, fileName: fileName)
                
            case .file(_, let _fileName, _):
                fileName = _fileName
            
            case .typeDeclaration,
                 .scopeAnnotation,
                 .referenceAnnotation,
                 .parameterAnnotation,
                 .configurationAnnotation:
                break
            }
        }

        // Insert the resolvers for which we don't know the type.
        for token in ExprSequence(exprs: syntaxTrees).referenceAnnotations {
            graph.insertResolver(with: token.value)
        }
    }
    
    private func linkResolvers(from syntaxTrees: [Expr]) throws {
        
        for ast in syntaxTrees {
            if let file = ast.toFile() {
                try linkResolvers(from: file.types, fileName: file.name)
            } else {
                throw InspectorError.invalidAST(.unknown, unexpectedExpr: ast)
            }
        }
    }
    
    private func linkResolvers(from exprs: [Expr], fileName: String) throws {
        
        for expr in exprs {
            guard let (token, children) = expr.toTypeDeclaration() else {
                throw InspectorError.invalidAST(.file(fileName), unexpectedExpr: expr)
            }

            let resolver = graph.resolver(typed: token.value.type,
                                          accessLevel: token.value.accessLevel,
                                          line: token.line,
                                          fileName: fileName)
            
            try resolver.update(with: children,
                                fileName: fileName,
                                graph: graph)
        }
    }
}

private extension Dependency {
    
    convenience init(dependentResolver: Resolver,
                     registerAnnotation: TokenBox<RegisterAnnotation>,
                     scopeAnnotation: ScopeAnnotation? = nil,
                     config: [TokenBox<ConfigurationAnnotation>],
                     fileName: String,
                     graph: Graph) throws {

        guard let associatedResolver = graph.resolver(named: registerAnnotation.value.name) else {
            throw InspectorError.invalidGraph(registerAnnotation.printableDependency(file: fileName),
                                              underlyingError: .unresolvableDependency(history: []))
        }
        
        let config = DependencyConfiguration(with: config.map { $0.value.attribute })
        
        self.init(name: registerAnnotation.value.name,
                  scope: scopeAnnotation?.scope ?? .`default`,
                  config: config,
                  line: registerAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
    
    convenience init(dependentResolver: Resolver,
                     referenceAnnotation: TokenBox<ReferenceAnnotation>,
                     config: [TokenBox<ConfigurationAnnotation>],
                     fileName: String,
                     graph: Graph) throws {

        guard let associatedResolver = graph.resolver(named: referenceAnnotation.value.name) else {
            throw InspectorError.invalidGraph(referenceAnnotation.printableDependency(file: fileName),
                                              underlyingError: .unresolvableDependency(history: []))
        }

        let config = DependencyConfiguration(with: config.map { $0.value.attribute })

        self.init(name: referenceAnnotation.value.name,
                  config: config,
                  line: referenceAnnotation.line,
                  file: fileName,
                  associatedResolver: associatedResolver,
                  dependentResovler: dependentResolver)
    }
}

private extension Resolver {
    
    func update(with children: [Expr],
                fileName: String,
                graph: Graph) throws {

        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var referenceAnnotations: [TokenBox<ReferenceAnnotation>] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        var configurationAnnotations: [ConfigurationAttributeTarget: [TokenBox<ConfigurationAnnotation>]] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, let children):
                let resolver = graph.resolver(typed: injectableType.value.type,
                                              accessLevel: injectableType.value.accessLevel,
                                              line: injectableType.line,
                                              fileName: fileName)

                try resolver.update(with: children,
                                    fileName: fileName,
                                    graph: graph)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .referenceAnnotation(let referenceAnnotation):
                referenceAnnotations.append(referenceAnnotation)

            case .scopeAnnotation(let scopeAnnotation):
                scopeAnnotations[scopeAnnotation.value.name] = scopeAnnotation.value
                
            case .configurationAnnotation(let configurationAnnotation):
                let target = configurationAnnotation.value.target
                configurationAnnotations[target] = (configurationAnnotations[target] ?? []) + [configurationAnnotation]
                
            case .file,
                 .parameterAnnotation:
                break
            }
        }
        
        self.config = ResolverConfiguration(with: configurationAnnotations[.`self`]?.map { $0.value })
        
        for registerAnnotation in registerAnnotations {
            let name = registerAnnotation.value.name
            let dependency = try Dependency(dependentResolver: self,
                                            registerAnnotation: registerAnnotation,
                                            scopeAnnotation: scopeAnnotations[name],
                                            config: configurationAnnotations[.dependency(name: name)] ?? [],
                                            fileName: fileName,
                                            graph: graph)
            let index = DependencyIndex(type: dependency.associatedResolver.type, name: dependency.name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
        
        for referenceAnnotation in referenceAnnotations {
            let name = referenceAnnotation.value.name
            let dependency = try Dependency(dependentResolver: self,
                                            referenceAnnotation: referenceAnnotation,
                                            config: configurationAnnotations[.dependency(name: name)] ?? [],
                                            fileName: fileName,
                                            graph: graph)
            let index = DependencyIndex(type: dependency.associatedResolver.type, name: name)
            dependencies[index] = dependency
            dependency.associatedResolver.dependents.append(self)
        }
    }
}

// MARK: - Resolution Check

private extension Dependency {
    
    func resolve(with cache: inout Set<ResolutionCacheIndex>) throws {
        
        if dependentResovler.accessLevel == .public && dependentResovler.dependents.isEmpty {
            guard associatedResolver.referredTypes.count <= 1 else {
                let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [])
                throw InspectorError.invalidGraph(printableDependency, underlyingError: underlyingError)
            }
            return
        }
        
        guard isReference && !config.customRef else {
            return
        }

        do {

            if try dependentResovler.checkIsolation(history: []) == false {
                return
            }
            
            let index = DependencyIndex(type: associatedResolver.type, name: name)
            for dependent in dependentResovler.dependents {
                try dependent.resolveDependency(index: index, cache: &cache)
            }
            
        } catch let error as InspectorAnalysisError {
            throw InspectorError.invalidGraph(printableDependency, underlyingError: error)
        }
    }
}

private extension Resolver {
    
    func resolveDependency(index: DependencyIndex, cache: inout Set<ResolutionCacheIndex>) throws {
        let cacheIndex = ResolutionCacheIndex(resolver: self, dependencyIndex: index)
        guard !cache.contains(cacheIndex) else {
            return
        }

        var visitedResolvers = Set<Resolver>()
        var history = [InspectorAnalysisHistoryRecord]()
        try resolveDependency(index: index, visitedResolvers: &visitedResolvers, history: &history)
        
        cache.insert(cacheIndex)
    }
    
    private func resolveDependency(index: DependencyIndex, visitedResolvers: inout Set<Resolver>, history: inout [InspectorAnalysisHistoryRecord]) throws {
        if visitedResolvers.contains(self) {
            throw InspectorAnalysisError.cyclicDependency(history: history.cyclicDependencyDetection)
        }
        visitedResolvers.insert(self)

        history.append(.triedToResolveDependencyInType(printableDependency(name: index.name), stepCount: history.resolutionSteps.count))
        
        if let dependency = dependencies[index] {
            if dependency.isReference && accessLevel == .public {
                return
            }
            if let scope = dependency.scope, (dependency.config.customRef && scope.allowsAccessFromChildren) || scope.allowsAccessFromChildren {
                return
            }
            history.append(.foundUnaccessibleDependency(dependency.printableDependency))
        } else {
            history.append(.dependencyNotFound(printableDependency(name: index.name)))
        }

        if try checkIsolation(history: history) == false {
           return
        }
        
        for dependent in dependents {
            var visitedResolversCopy = visitedResolvers
            if let _ = try? dependent.resolveDependency(index: index, visitedResolvers: &visitedResolversCopy, history: &history) {
                return
            }
        }
        
        throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
    }
}

// MARK: - Isolation Check

private extension Resolver {
    
    func checkIsolation(history: [InspectorAnalysisHistoryRecord]) throws -> Bool {
        
        let connectedReferents = dependents.filter { !$0.config.isIsolated }
        
        switch (dependents.isEmpty, config.isIsolated) {
        case (true, false):
            throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
            
        case (false, true) where !connectedReferents.isEmpty:
            throw InspectorAnalysisError.isolatedResolverCannotHaveReferents(type: type,
                                                                             referents: connectedReferents.map { $0.printableResolver })

        case (true, true):
            return false
            
        case (false, _):
            return true
        }
    }
}

// MARK: - Build Check

private extension Dependency {
    
    func build(with buildCache: inout Set<BuildCacheIndex>) throws {
        let buildCacheIndex = BuildCacheIndex(resolver: associatedResolver, scope: scope)
        guard !buildCache.contains(buildCacheIndex) else {
            return
        }
        buildCache.insert(buildCacheIndex)
        
        guard !isReference && !config.customRef else {
            return
        }
        
        guard let scope = scope, !scope.allowsAccessFromChildren else {
            return
        }
        
        var visitedResolvers = Set<Resolver>()
        try associatedResolver.buildDependencies(from: self, visitedResolvers: &visitedResolvers, history: [])
    }
}

private extension Resolver {
    
    func buildDependencies(from sourceDependency: Dependency, visitedResolvers: inout Set<Resolver>, history: [InspectorAnalysisHistoryRecord]) throws {

        if visitedResolvers.contains(self) {
            throw InspectorError.invalidGraph(sourceDependency.printableDependency,
                                              underlyingError: .cyclicDependency(history: history.cyclicDependencyDetection))
        }
        visitedResolvers.insert(self)
        
        var history = history
        history.append(.triedToBuildType(printableResolver, stepCount: history.buildSteps.count))
        
        for dependency in dependencies.orderedValues {
            var visitedResolversCopy = visitedResolvers
            try dependency.associatedResolver.buildDependencies(from: sourceDependency,
                                                                visitedResolvers: &visitedResolversCopy,
                                                                history: history)
        }
    }
}

// MARK: - Utils

private extension Dependency {
    
    var isReference: Bool {
        return scope == nil
    }
}

// MARK: - Conversions

private extension TokenBox where T == RegisterAnnotation {
    
    func printableDependency(file: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: FileLocation(line: line, file: file),
                                   name: value.name,
                                   type: value.type)
    }
}

private extension TokenBox where T == ReferenceAnnotation {
    
    func printableDependency(file: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: FileLocation(line: line, file: file),
                                   name: value.name,
                                   type: value.type)
    }
}

private extension Dependency {
    
    var printableDependency: PrintableDependency {
        return PrintableDependency(fileLocation: fileLocation,
                                   name: name,
                                   type: associatedResolver.type)
    }
}

private extension Resolver {
    
    func printableDependency(name: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: fileLocation, name: name, type: type)
    }
    
    var printableResolver: PrintableResolver {
        return PrintableResolver(fileLocation: fileLocation, type: type)
    }
}

// MARK: - Hashable

extension Resolver: Hashable {
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Resolver, rhs: Resolver) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Dependency: Hashable {

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Dependency, rhs: Dependency) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension DependencyIndex: Hashable {
    
    var hashValue: Int {
        return (type?.hashValue ?? 0) ^ name.hashValue
    }
    
    static func ==(lhs: DependencyIndex, rhs: DependencyIndex) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.type == rhs.type else { return false }
        return true
    }
}

extension ResolutionCacheIndex: Hashable {

    var hashValue: Int {
        return resolver.hashValue ^ dependencyIndex.hashValue
    }
    
    static func ==(lhs: ResolutionCacheIndex, rhs: ResolutionCacheIndex) -> Bool {
        guard lhs.resolver == rhs.resolver else { return false }
        guard lhs.dependencyIndex == rhs.dependencyIndex else { return false }
        return true
    }
}

extension BuildCacheIndex: Hashable {
    
    var hashValue: Int {
        return resolver.hashValue ^ (scope?.hashValue ?? 0)
    }
    
    static func ==(lhs: BuildCacheIndex, rhs: BuildCacheIndex) -> Bool {
        guard lhs.resolver == rhs.resolver else { return false }
        guard lhs.scope == rhs.scope else { return false }
        return true
    }
}
