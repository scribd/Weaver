//
//  Generator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import StencilSwiftKit
import PathKit

public final class Generator {
    
    private let dependencyGraph: DependencyGraph

    private let templatePath: Path
    
    public init(dependencyGraph: DependencyGraph, template path: Path? = nil) throws {

        self.dependencyGraph = dependencyGraph
        
        templatePath = path ?? Path("/usr/local/share/weaver/Resources/dependency_resolver.stencil")
    }
    
    public func generate() throws -> [(file: String, data: String?)] {

        let templateString: String = try templatePath.read()
        let environment = stencilSwiftEnvironment()
        
        let templateClass = StencilSwiftTemplate(templateString: templateString,
                                                 environment: environment,
                                                 name: nil)

        return try dependencyGraph.dependencyContainersByFile.orderedKeyValues.map { item in
            
            let dependencyContainers = item.value.compactMap { DependencyContainerViewModel($0, dependencyGraph: dependencyGraph) }

            guard !dependencyContainers.isEmpty else {
                return (file: item.key, data: nil)
            }
            
            let context: [String: Any] = ["dependencyContainers": dependencyContainers,
                                          "imports": dependencyGraph.importsByFile[item.key] ?? []]
            let string = try templateClass.render(context)
            
            return (file: item.key, data: string.compacted())
        }
    }
}

// MARK: - ViewModels

private struct RegistrationViewModel {
    
    let name: String
    let type: Type
    let abstractType: Type
    let scope: String
    let customRef: Bool
    let parameters: [DependencyViewModel]
    let hasReferences: Bool
    let hasBuilder: Bool
    let hasDependencyContainer: Bool
    let isTransient: Bool
    let isWeak: Bool
    
    init(_ dependency: Dependency, dependencyGraph: DependencyGraph) {
        name = dependency.dependencyName
        type = dependency.type
        abstractType = dependency.abstractType
        scope = dependency.configuration.scope.rawValue
        customRef = dependency.configuration.customRef
        
        if let dependencyContainer = dependencyGraph.dependencyContainersByType[dependency.type.index] {
            parameters = dependencyContainer.parameters.orderedValues.map {
                DependencyViewModel($0, context: dependency.source, dependencyGraph: dependencyGraph)
            }
            hasReferences = !dependencyContainer.allReferences.isEmpty
            hasBuilder = dependencyContainer.hasBuilder
            hasDependencyContainer = dependencyContainer.hasDependencies
        } else {
            parameters = []
            hasReferences = false
            hasBuilder = false
            hasDependencyContainer = false
        }

        isTransient = dependency.scope == .transient
        isWeak = dependency.scope == .weak
    }
}

private struct DependencyViewModel {

    let name: String
    let type: Type
    let abstractType: Type
    let parameters: [DependencyViewModel]

    init(_ dependency: Dependency, context: DependencyContainer? = nil, dependencyGraph: DependencyGraph) {
        
        name = dependency.dependencyName
        type = context?.parameters[dependency.dependencyName]?.type ?? dependency.type
        abstractType = context?.parameters[dependency.dependencyName]?.abstractType ?? dependency.abstractType
        
        let parameters = dependencyGraph.dependencyContainersByType[dependency.type.index]?.parameters ?? OrderedDictionary()
        if parameters.orderedValues.isEmpty, let types = dependencyGraph.typesByName[name] {
            var _parameters = [DependencyViewModel]()
            for type in types {
                if let parameters = dependencyGraph.dependencyContainersByType[type.index]?.parameters {
                    _parameters = parameters.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
                    break
                }
            }
            self.parameters = _parameters
        } else {
            self.parameters = parameters.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
        }
    }
}

private struct DependencyContainerViewModel {

    let targetType: Type?
    let registrations: [RegistrationViewModel]
    let references: [DependencyViewModel]
    let directReferences: [DependencyViewModel]
    let parameters: [DependencyViewModel]
    let embeddingTypes: [Type]?
    let isRoot: Bool
    let isPublic: Bool
    let doesSupportObjc: Bool
    let injectableDependencies: [DependencyContainerViewModel]?
    
    init?(_ dependencyContainer: DependencyContainer, dependencyGraph: DependencyGraph, depth: Int = 0) {

        guard let type = dependencyContainer.type, dependencyContainer.hasDependencies else {
            return nil
        }
        
        targetType = type
        registrations = dependencyContainer.registrations.orderedValues.map { RegistrationViewModel($0, dependencyGraph: dependencyGraph) }
        directReferences = dependencyContainer.references.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
        references = dependencyContainer.allReferences.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
        parameters = dependencyContainer.parameters.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph)}
        embeddingTypes = dependencyContainer.embeddingTypes
        isRoot = dependencyContainer.isRoot
        isPublic = dependencyContainer.isPublic
        doesSupportObjc = dependencyContainer.doesSupportObjc
        injectableDependencies = dependencyContainer.injectableDependencies(dependencyGraph: dependencyGraph, depth: depth)
    }
}

// MARK: - Utils

private extension String {
    
    func compacted() -> String {
        return split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
}

private extension DependencyContainer {
    
    var hasDependencies: Bool {
        return !registrations.orderedValues.isEmpty || !references.orderedValues.isEmpty || !parameters.orderedValues.isEmpty
    }
    
    var allReferences: [ResolvableDependency] {
        var visitedDependencyContainters = Set<DependencyContainer>()
        return collectAllReferences(&visitedDependencyContainters)
    }
    
    private func collectAllReferences(_ visitedDependencyContainers: inout Set<DependencyContainer>) -> [ResolvableDependency] {
        guard !visitedDependencyContainers.contains(self) else { return [] }
        visitedDependencyContainers.insert(self)

        let directReferences = references.orderedValues
        let indirectReferences = registrations.orderedValues.flatMap { $0.target.collectAllReferences(&visitedDependencyContainers) }

        let referencesByName = OrderedDictionary<String, ResolvableDependency>()
        (directReferences + indirectReferences).forEach {
            referencesByName[$0.dependencyName] = $0
        }
        
        let registrationNames = Set(registrations.orderedValues.map { $0.dependencyName })
        return referencesByName.orderedValues.filter {
            !registrationNames.contains($0.dependencyName)
        }
    }
    
    var isRoot: Bool {
        return sources.isEmpty
    }
    
    var hasBuilder: Bool {
        return !parameters.orderedValues.isEmpty || !allReferences.isEmpty
    }
    
    var isPublic: Bool {
        switch accessLevel {
        case .internal:
            return false
        case .public:
            return true
        }
    }
    
    func injectableDependencies(dependencyGraph: DependencyGraph, depth: Int) -> [DependencyContainerViewModel]? {
        guard depth == 0 else { return nil }
        return registrations.orderedValues.compactMap {
            DependencyContainerViewModel($0.target, dependencyGraph: dependencyGraph, depth: depth + 1)
        }
    }
}

