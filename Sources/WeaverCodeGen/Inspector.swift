//
//  Inspector.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation

// MARK: - Inspector

public final class Inspector {

    private let dependencyGraph: DependencyGraph
    
    private lazy var resolutionCache = [InspectorCacheIndex: Dependency]()
    private lazy var buildCache = Set<InspectorCacheIndex>()
    
    public init(dependencyGraph: DependencyGraph) {
        self.dependencyGraph = dependencyGraph
    }
    
    public func validate() throws {
        for dependency in dependencyGraph.dependencies {
            try validateConfiguration(of: dependency)
            if dependency.kind.isResolvable {
                try validatePropertyWrapper(of: dependency)
                try resolve(dependency)
                try build(dependency)
            }
        }
    }
}

// MARK: - Inspection Level

enum InspectionLevel {
    case aggressive
    case permissive
}

// MARK: - Resolution Check

extension Inspector {
    
    @discardableResult
    func resolve(_ dependency: Dependency) throws -> [ConcreteType: Dependency] {
        let source = try dependencyGraph.dependencyContainer(for: dependency.source, at: dependency.fileLocation)
        return try resolve(dependency, from: source)
    }
    
    func resolve(_ dependency: Dependency,
                 from source: DependencyContainer,
                 inspectionLevel: InspectionLevel = .aggressive) throws -> [ConcreteType: Dependency] {
        
        guard dependency.kind == .reference else {
            return [source.type: dependency]
        }

        if source.accessLevel == .public && source.sources.isEmpty {
            return [source.type: dependency]
        }
                
        do {
            if inspectionLevel == .aggressive {
                guard try checkIsolation(of: source, history: []) else { return [:] }
            }
            
            let sources = [source.type] + Array(source.sources)
            return try sources.reduce(into: [ConcreteType: Dependency]()) { foundDependencies, sourceType in
                let source = try dependencyGraph.dependencyContainer(for: sourceType, at: source.fileLocation)
                foundDependencies[sourceType] = try resolve(dependency, in: source)
            }
        } catch let error as InspectorAnalysisError {
            if source.sources.isEmpty {
                let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                    .triedToResolveDependencyInRootType(source)
                ])
                throw InspectorError.invalidDependencyGraph(dependency, underlyingError: underlyingError)
            } else {
                throw InspectorError.invalidDependencyGraph(dependency, underlyingError: error)
            }
        }
    }
}

private extension Inspector {
    
    func resolve(_ dependency: Dependency, in dependencyContainer: DependencyContainer) throws -> Dependency {
        
        let cacheIndex = InspectorCacheIndex(dependency, dependencyContainer)
        if let foundDependency = resolutionCache[cacheIndex] {
            return foundDependency
        }
        
        var visitedDependencyContainers = Set<ObjectIdentifier>()
        var history = [InspectorAnalysisHistoryRecord]()
        history.reserveCapacity(dependencyGraph.dependencyContainers.orderedKeys.count)
        let foundDependency = try resolve(dependency,
                                          in: dependencyContainer,
                                          visitedDependencyContainers: &visitedDependencyContainers,
                                          history: &history)

        resolutionCache[cacheIndex] = foundDependency
        return foundDependency
    }
    
    private func resolve(_ dependency: Dependency,
                         in dependencyContainer: DependencyContainer,
                         visitedDependencyContainers: inout Set<ObjectIdentifier>,
                         history: inout [InspectorAnalysisHistoryRecord]) throws -> Dependency {

        if visitedDependencyContainers.contains(ObjectIdentifier(dependencyContainer)) {
            throw InspectorAnalysisError.cyclicDependency(history: history.cyclicDependencyDetection)
        }
        visitedDependencyContainers.insert(ObjectIdentifier(dependencyContainer))

        history.append(.triedToResolveDependencyInType(dependency, stepCount: history.resolutionSteps.count))

        do {
            if let foundDependency = try resolveRegistration(for: dependency, in: dependencyContainer) {
                return foundDependency
            }
            history.append(.dependencyNotFound(dependency, in: dependencyContainer))
        } catch let error as InspectorAnalysisHistoryRecord {
            history.append(error)
        }

        guard try checkIsolation(of: dependencyContainer, history: history) else { return dependency }
        
        for source in dependencyContainer.sources {
            let source = try dependencyGraph.dependencyContainer(for: source, at: dependency.fileLocation)
            
            var visitedDependencyContainersCopy = visitedDependencyContainers
            do {
                return try resolve(dependency,
                                   in: source,
                                   visitedDependencyContainers: &visitedDependencyContainersCopy,
                                   history: &history)
            } catch {
                // no-op
            }
        }
        
        throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
    }
    
    func resolveRegistration(for dependency: Dependency,
                             in dependencyContainer: DependencyContainer) throws -> Dependency? {
        
        var _dependencyNames: Set<String>?
        if let concreteType = dependency.type.concreteType {
            _dependencyNames = dependencyContainer.dependencyNamesByConcreteType[concreteType]
        } else if dependency.type.abstractType.isEmpty == false {
            let dependencyNames = Set(dependency.type.abstractType.flatMap { abstractType in
                dependencyContainer.dependencyNamesByAbstractType[abstractType] ?? []
            })
            if dependencyNames.isEmpty == false {
                _dependencyNames = dependencyNames
            }
        }
        
        if let dependencyNames = _dependencyNames {
            
            if dependencyNames.contains(dependency.dependencyName) {
                guard let foundDependency = dependencyContainer.dependencies[dependency.dependencyName] else { return nil }
                
                guard foundDependency.type ~= dependency.type else {
                    throw InspectorAnalysisHistoryRecord.typeMismatch(dependency, candidate: foundDependency)
                }

                switch foundDependency.kind {
                case .reference where dependencyContainer.accessLevel == .public:
                    return foundDependency
                case .parameter,
                     .registration:
                    return foundDependency
                case .reference:
                    return nil
                }
            } else {
                let foundDependencies = dependencyContainer.dependencies.orderedValues.filter {
                    $0.kind != .reference && $0.type ~= dependency.type
                }
                guard foundDependencies.count < 2 else {
                    throw InspectorAnalysisHistoryRecord.implicitDependency(dependency, candidates: foundDependencies)
                }

                guard foundDependencies.count == 1 else {
                    let _candidate = dependencyContainer.dependencies.orderedValues.lazy.filter {
                        $0.kind != .reference
                    }.filter {
                        $0.type.concreteType == dependency.type.concreteType ||
                        dependency.type.abstractType.isSuperset(of: $0.type.concreteType) ||
                        $0.type.abstractType.isSuperset(of: dependency.type.concreteType)
                    }.first
                    
                    if let candidate = _candidate {
                        throw InspectorAnalysisHistoryRecord.typeMismatch(dependency, candidate: candidate)
                    } else {
                        return nil
                    }
                }
                
                return foundDependencies.first!
            }
            
        } else {
            
            let concreteTypes = Set(dependency.type.abstractType.flatMap { type -> [ConcreteType] in
                guard let concreteTypes = dependencyGraph.concreteTypes[type] else { return [] }
                return Array(concreteTypes.values)
            })
            
            if concreteTypes.count > 1 {
                let candidates = concreteTypes.flatMap { type -> [Dependency] in
                    guard let dependencyNames = dependencyContainer.dependencyNamesByConcreteType[type] else { return [] }
                    return dependencyNames.compactMap { dependencyContainer.dependencies[$0] }
                }.sorted { $0.dependencyName < $1.dependencyName }
                
                throw InspectorAnalysisHistoryRecord.implicitType(dependency, candidates: candidates)
            } else if let concreteType = dependency.type.concreteType,
                let abstractTypes = dependencyGraph.abstractTypes[concreteType],
                abstractTypes.value.isEmpty == false {
                
                let candidates = abstractTypes.flatMap { type -> [Dependency] in
                    guard let dependencyNames = dependencyContainer.dependencyNamesByAbstractType[type] else { return [] }
                    return dependencyNames.compactMap { dependencyContainer.dependencies[$0] }
                }.sorted { $0.dependencyName < $1.dependencyName }
                
                throw InspectorAnalysisHistoryRecord.implicitType(dependency, candidates: candidates)
            } else if let candidate = dependencyContainer.dependencies[dependency.dependencyName] {
                throw InspectorAnalysisHistoryRecord.typeMismatch(dependency, candidate: candidate)
            } else {
                return nil
            }
        }
    }
}

// MARK: - Isolation Check

private extension Inspector {
    
    func checkIsolation(of dependencyContainer: DependencyContainer,
                        history: [InspectorAnalysisHistoryRecord]) throws -> Bool {

        let connectedSources = try dependencyContainer.sources.compactMap { source -> DependencyContainer? in
            let source = try dependencyGraph.dependencyContainer(for: source, at: dependencyContainer.fileLocation)
            return source.configuration.isIsolated ? nil : source
        }
        
        switch (dependencyContainer.sources.isEmpty, dependencyContainer.configuration.isIsolated) {
        case (true, false):
            throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
            
        case (false, true) where connectedSources.isEmpty == false:
            throw InspectorAnalysisError.isolatedResolverCannotHaveReferents(
                type: dependencyContainer.type.value,
                referents: connectedSources
            )

        case (true, true):
            return false
            
        case (false, _):
            return true
        }
    }
}

// MARK: - Build Check

private extension Inspector {
    
    func build(_ dependency: Dependency) throws {
        
        let target = try dependencyGraph.dependencyContainer(for: dependency)
        
        let cacheIndex = InspectorCacheIndex(dependency, target)
        guard !buildCache.contains(cacheIndex) else { return }
        buildCache.insert(cacheIndex)
        
        guard dependency.kind != .reference && dependency.configuration.customBuilder == nil else { return }
        
        var visitedDependencyContainers = Set<ConcreteType>()
        try buildDependencies(of: target,
                              from: dependency,
                              visitedDependencyContainers: &visitedDependencyContainers,
                              history: [])
    }
}

private extension Inspector {
    
    func buildDependencies(of dependencyContainer: DependencyContainer,
                           from sourceDependency: Dependency,
                           visitedDependencyContainers: inout Set<ConcreteType>,
                           history: [InspectorAnalysisHistoryRecord]) throws {

        if visitedDependencyContainers.contains(dependencyContainer.type) {
            let visitedASelfReferenced = try visitedDependencyContainers.contains { type in
                let dependencyContainer = try dependencyGraph.dependencyContainer(for: type)
                return try dependencyGraph.hasSelfReference(dependencyContainer)
            }
            guard visitedASelfReferenced == false else { return }
            throw InspectorError.invalidDependencyGraph(sourceDependency, underlyingError: .cyclicDependency(history: history.cyclicDependencyDetection))
        }
        visitedDependencyContainers.insert(dependencyContainer.type)
        
        var history = history
        history.append(.triedToBuildType(dependencyContainer, stepCount: history.buildSteps.count))
        
        for dependency in dependencyContainer.dependencies.orderedValues where dependency.kind.isResolvable {
            var visitedDependencyContainersCopy = visitedDependencyContainers
            
            let target = try dependencyGraph.dependencyContainer(for: dependency)
            try buildDependencies(of: target,
                                  from: sourceDependency,
                                  visitedDependencyContainers: &visitedDependencyContainersCopy,
                                  history: history)
        }
    }
}

// MARK: - Configuration check

private extension Inspector {
    
    func validateConfiguration(of dependency: Dependency) throws {
        switch dependency.configuration.scope {
        case .container where dependency.kind.isResolvable:
            let target = try dependencyGraph.dependencyContainer(for: dependency)
            if target.parameters.isEmpty == false {
                throw InspectorError.invalidContainerScope(dependency)
            }
        case .weak:
            if dependency.kind == .parameter && dependency.type.anyType.isOptional == false {
                throw InspectorError.weakParameterHasToBeOptional(dependency)
            }
        case .lazy,
             .transient,
             .container:
            break
        }
    }
}

// MARK: - Property Wrappers check

private extension Inspector {
    
    func validatePropertyWrapper(of dependency: Dependency) throws {
        guard dependency.annotationStyle == .propertyWrapper else { return }

        let target = try dependencyGraph.dependencyContainer(for: dependency)
        
        let expectedType: CompositeType
        if target.parameters.isEmpty == false {
            expectedType = .closure(Closure(
                tuple: target.parameters.map { TupleComponent(alias: nil, name: nil, type: $0.type.anyType) },
                returnType: dependency.type.anyType
            ))
        } else {
            expectedType = dependency.type.anyType
        }

        let actualType: CompositeType
        if dependency.closureParameters.isEmpty == false {
            actualType = .closure(Closure(
                tuple: dependency.closureParameters.map { TupleComponent(alias: nil, name: nil, type: $0.type) },
                returnType: dependency.type.anyType
            ))
        } else {
            actualType = dependency.type.anyType
        }
        
        guard expectedType == actualType else {
            throw InspectorError.invalidDependencyGraph(
                dependency,
                underlyingError: .resolverTypeMismatch(expectedType: expectedType, actualType: actualType)
            )
        }
    }
}

// MARK: - Indexes

struct InspectorCacheIndex: Hashable, Equatable {

    let dependency: ObjectIdentifier
    let dependencyContainer: ObjectIdentifier
    
    init(_ dependency: Dependency, _ dependencyContainer: DependencyContainer) {
        self.dependency = ObjectIdentifier(dependency)
        self.dependencyContainer = ObjectIdentifier(dependencyContainer)
    }
}
