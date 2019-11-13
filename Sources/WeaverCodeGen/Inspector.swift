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
    
    private lazy var resolutionCache = Set<ResolutionCacheIndex>()
    private lazy var buildCache = Set<BuildCacheIndex>()
    
    public init(dependencyGraph: DependencyGraph) {
        self.dependencyGraph = dependencyGraph
    }
    
    public func validate() throws {
        for dependency in dependencyGraph.dependencies {
            try dependency.resolve(with: &resolutionCache)
            try dependency.build(with: &buildCache)
        }
    }
}

// MARK: - Resolution Check

private extension ResolvableDependency {
    
    func resolve(with cache: inout Set<ResolutionCacheIndex>) throws {
        
        if source.accessLevel == .public && source.sources.isEmpty {
            guard target.referencedTypes.count <= 1 else {
                let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [])
                throw InspectorError.invalidDependencyGraph(printableDependency, underlyingError: underlyingError)
            }
            return
        }
        
        guard isReference && configuration.customBuilder == nil else {
            return
        }

        do {

            if try source.checkIsolation(history: []) == false {
                return
            }
            
            let index = DependencyIndex(name: dependencyName, type: target.type)
            for dependent in source.sources {
                try dependent.resolveDependency(index: index, cache: &cache)
            }
            
        } catch let error as InspectorAnalysisError {
            throw InspectorError.invalidDependencyGraph(printableDependency, underlyingError: error)
        }
    }
}

private extension DependencyContainer {
    
    func resolveDependency(index: DependencyIndex, cache: inout Set<ResolutionCacheIndex>) throws {
        
        let cacheIndex = ResolutionCacheIndex(dependencyContainer: self, dependencyIndex: index)
        guard !cache.contains(cacheIndex) else {
            return
        }

        var visitedDependencyContainers = Set<DependencyContainer>()
        var history = [InspectorAnalysisHistoryRecord]()
        try resolveDependency(index: index,
                              visitedDependencyContainers: &visitedDependencyContainers,
                              history: &history)
        
        cache.insert(cacheIndex)
    }
    
    private func resolveDependency(index: DependencyIndex,
                                   visitedDependencyContainers: inout Set<DependencyContainer>,
                                   history: inout [InspectorAnalysisHistoryRecord]) throws {

        if visitedDependencyContainers.contains(self) {
            throw InspectorAnalysisError.cyclicDependency(history: history.cyclicDependencyDetection)
        }
        visitedDependencyContainers.insert(self)

        history.append(.triedToResolveDependencyInType(printableDependency(name: index.name), stepCount: history.resolutionSteps.count))

        guard dependency(for: index) == nil else {
            return
        }
        
        history.append(.dependencyNotFound(printableDependency(name: index.name)))

        if try checkIsolation(history: history) == false {
           return
        }
        
        for source in sources {
            var visitedDependencyContainersCopy = visitedDependencyContainers
            if let _ = try? source.resolveDependency(index: index,
                                                     visitedDependencyContainers: &visitedDependencyContainersCopy,
                                                     history: &history) {
                return
            }
        }
        
        throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
    }
}

// MARK: - Isolation Check

private extension DependencyContainer {
    
    func checkIsolation(history: [InspectorAnalysisHistoryRecord]) throws -> Bool {
        
        let connectedSources = sources.filter { !$0.configuration.isIsolated }
        
        switch (sources.isEmpty, configuration.isIsolated) {
        case (true, false):
            throw InspectorAnalysisError.unresolvableDependency(history: history.unresolvableDependencyDetection)
            
        case (false, true) where !connectedSources.isEmpty:
            throw InspectorAnalysisError.isolatedResolverCannotHaveReferents(
                type: type,
                referents: connectedSources.map { $0.printableResolver }
            )

        case (true, true):
            return false
            
        case (false, _):
            return true
        }
    }
}

// MARK: - Build Check

private extension ResolvableDependency {
    
    func build(with buildCache: inout Set<BuildCacheIndex>) throws {
        
        let buildCacheIndex = BuildCacheIndex(dependencyContainer: target, scope: scope)
        guard !buildCache.contains(buildCacheIndex) else {
            return
        }
        buildCache.insert(buildCacheIndex)
        
        guard isReference == false && configuration.customBuilder == nil else {
            return
        }
        
        var visitedDependencyContainers = Set<DependencyContainer>()
        try target.buildDependencies(from: self,
                                     visitedDependencyContainers: &visitedDependencyContainers,
                                     history: [])
    }
}

private extension DependencyContainer {
    
    func buildDependencies(from sourceDependency: ResolvableDependency,
                           visitedDependencyContainers: inout Set<DependencyContainer>,
                           history: [InspectorAnalysisHistoryRecord]) throws {

        if visitedDependencyContainers.contains(self) {
            guard configuration.allowsCycles == false else { return }
            throw InspectorError.invalidDependencyGraph(sourceDependency.printableDependency,
                                              underlyingError: .cyclicDependency(history: history.cyclicDependencyDetection))
        }
        visitedDependencyContainers.insert(self)
        
        var history = history
        history.append(.triedToBuildType(printableResolver, stepCount: history.buildSteps.count))
        
        for dependency in orderedDependencies {
            var visitedDependencyContainersCopy = visitedDependencyContainers
            try dependency.target.buildDependencies(from: sourceDependency,
                                                    visitedDependencyContainers: &visitedDependencyContainersCopy,
                                                    history: history)
        }
    }
}

// MARK: - Conversions

extension TokenBox where T == RegisterAnnotation {
    
    func printableDependency(file: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: FileLocation(line: line, file: file),
                                   name: value.name,
                                   type: value.type)
    }
}

extension TokenBox where T == ReferenceAnnotation {
    
    func printableDependency(file: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: FileLocation(line: line, file: file),
                                   name: value.name,
                                   type: value.type)
    }
}

private extension ResolvableDependency {
    
    var printableDependency: PrintableDependency {
        return PrintableDependency(fileLocation: fileLocation,
                                   name: dependencyName,
                                   type: target.type)
    }
}

private extension DependencyContainer {
    
    func printableDependency(name: String) -> PrintableDependency {
        return PrintableDependency(fileLocation: fileLocation, name: name, type: type)
    }
    
    var printableResolver: PrintableResolver {
        return PrintableResolver(fileLocation: fileLocation, type: type)
    }
}


// MARK: - Indexes

private struct ResolutionCacheIndex: Hashable, Equatable {
    let dependencyContainer: DependencyContainer
    let dependencyIndex: DependencyIndex
}

private struct BuildCacheIndex: Hashable, Equatable {
    let dependencyContainer: DependencyContainer
    let scope: Scope?
}
