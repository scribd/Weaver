//
//  SwiftGenerator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import StencilSwiftKit
import PathKit

public final class SwiftGenerator {
    
    private let dependencyGraph: DependencyGraph
    
    private let detailedResolvers: Bool
    
    private let mainTemplate: StencilSwiftTemplate
    private let detailedResolversTemplate: StencilSwiftTemplate
    private let testsTemplate: StencilSwiftTemplate

    private let projectTargetName: String?    
    private let version: String
    
    public init(dependencyGraph: DependencyGraph,
                detailedResolvers: Bool,
                version: String,
                mainTemplatePath: Path,
                detailedResolversTemplatePath: Path,
                testsTemplatePath: Path,
                macrosTemplatePath: Path,
                projectTargetName: String?) throws {

        self.dependencyGraph = dependencyGraph
        self.detailedResolvers = detailedResolvers
        self.version = version
        self.projectTargetName = projectTargetName

        let environment = stencilSwiftEnvironment()

        let macrosTemplateString: String = try macrosTemplatePath.read()

        let mainTemplateString: String = try mainTemplatePath.read()
        mainTemplate = StencilSwiftTemplate(templateString: macrosTemplateString + mainTemplateString,
                                            environment: environment,
                                            name: nil)

        let detailedResolversTemplateString: String = try detailedResolversTemplatePath.read()
        detailedResolversTemplate = StencilSwiftTemplate(templateString: macrosTemplateString + detailedResolversTemplateString,
                                                         environment: environment,
                                                         name: nil)
        
        let testsTemplateString: String = try testsTemplatePath.read()
        testsTemplate = StencilSwiftTemplate(templateString: macrosTemplateString + testsTemplateString,
                                             environment: environment,
                                             name: nil)
    }
    
    public func generateMain() throws -> [(file: String, data: String?)] {

        var items: [(String, String?)] = try dependencyGraph.dependencyContainersByFile.orderedKeyValues.map { item in
            
            let dependencyContainers = item.value.compactMap { DependencyContainerViewModel($0, dependencyGraph: dependencyGraph) }

            guard !dependencyContainers.isEmpty else {
                return (file: item.key, data: nil)
            }
            
            let string = try renderMainTemplate(with: dependencyContainers,
                                                imports: dependencyGraph.importsByFile[item.key] ?? [])
            
            return (file: item.key, data: string.compacted())
        }
        
        if detailedResolvers {
            items.append((file: "DetailedResolvers.swift", data: try renderDetailedResolversTemplate(with: dependencyGraph, withHeader: true)))
        }
        
        return items
    }
    
    public func generateMain() throws -> String? {
        let dependencyContainers = dependencyGraph.dependencyContainersByFile.orderedValues.flatMap { dependencyContainer in
            return dependencyContainer.compactMap { DependencyContainerViewModel($0, dependencyGraph: dependencyGraph) }
        }

        var string = try renderMainTemplate(with: dependencyContainers, imports: dependencyGraph.orderedImports).compacted()
        guard !string.isEmpty else {
            return nil
        }
        
        if detailedResolvers {
            let detailedResolversString = try renderDetailedResolversTemplate(with: dependencyGraph, withHeader: false).compacted()
            if !detailedResolversString.isEmpty {
                string = [string, detailedResolversString].joined(separator: "\n")
            }
        }

        return string
    }
    
    public func generateTests() throws -> [(file: String, data: String?)] {
        return try dependencyGraph.dependencyContainersByFile.orderedKeyValues.map { item in
            
            let dependencyContainers = item.value.compactMap { DependencyContainerViewModel($0, dependencyGraph: dependencyGraph) }
            
            guard !dependencyContainers.isEmpty else {
                return (file: item.key, data: nil)
            }
            
            let string = try renderTestsTemplate(with: dependencyContainers,
                                                 imports: dependencyGraph.importsByFile[item.key] ?? [])
            
            return (file: item.key, data: string.compacted())
        }
    }
    
    public func generateTests() throws -> String? {
        let dependencyContainers = dependencyGraph.dependencyContainersByFile.orderedValues.flatMap { dependencyContainer in
            return dependencyContainer.compactMap { DependencyContainerViewModel($0, dependencyGraph: dependencyGraph) }
        }
        let string = try renderTestsTemplate(with: dependencyContainers, imports: dependencyGraph.orderedImports).compacted()
        return string.isEmpty ? nil : string
    }
}

// MARK: - Utils

private extension SwiftGenerator {
    
    func renderMainTemplate(with dependencyContainers: [DependencyContainerViewModel], imports: [String]) throws -> String {
        let context: [String: Any] = ["version": version,
                                      "dependencyContainers": dependencyContainers,
                                      "detailedResolvers": detailedResolvers,
                                      "imports": imports]
        return try mainTemplate.render(context)
    }
    
    func renderDetailedResolversTemplate(with dependencyGraph: DependencyGraph, withHeader header: Bool) throws -> String {
        let dependencies = dependencyGraph.dependencies
            .map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
            .reversed() // Set highest priority last
            .reduce(into: [:]) { $0[$1.abstractType.name] = $1 }
            .values.sorted(by: { $0.abstractType.name < $1.abstractType.name })

        let context: [String: Any] = ["dependencies": dependencies,
                                      "header": header,
                                      "imports": dependencyGraph.orderedImports]
        return try detailedResolversTemplate.render(context)
    }
    
    func renderTestsTemplate(with dependencyContainers: [DependencyContainerViewModel], imports: [String]) throws -> String {
        guard let projectTargetName = projectTargetName else {
            throw SwiftGeneratorError.missingProjectTargetName
        }
        
        let context: [String: Any] = ["version": version,
                                      "dependencyContainers": dependencyContainers,
                                      "detailedResolvers": detailedResolvers,
                                      "imports": imports,
                                      "project_target_name": projectTargetName]
        return try testsTemplate.render(context)
    }
}

// MARK: - ViewModels

private struct RegistrationViewModel {
    
    let name: String
    let type: Type
    let abstractType: Type
    let scope: String
    let customBuilder: String?
    let parameters: [DependencyViewModel]
    let hasReferences: Bool
    let hasBuilder: Bool
    let hasDependencyContainer: Bool
    let isTransient: Bool
    let isWeak: Bool
    let doesSupportObjc: Bool
    
    init(_ dependency: Dependency, dependencyGraph: DependencyGraph) {
        name = dependency.dependencyName
        type = dependency.type
        abstractType = dependency.abstractType
        scope = dependency.configuration.scope.rawValue
        customBuilder = dependency.configuration.customBuilder
        doesSupportObjc = dependency.configuration.doesSupportObjc
        
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
    let doesSupportObjc: Bool

    init(_ dependency: Dependency, context: DependencyContainer? = nil, dependencyGraph: DependencyGraph) {
        
        name = dependency.dependencyName
        type = context?.parameters[dependency.dependencyName]?.type ?? dependency.type
        abstractType = context?.parameters[dependency.dependencyName]?.abstractType ?? dependency.abstractType
        doesSupportObjc = dependency.configuration.doesSupportObjc
        
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
    
    init(_ registration: RegistrationViewModel) {
        name = registration.name
        type = registration.type
        abstractType = registration.abstractType
        parameters = registration.parameters
        doesSupportObjc = registration.doesSupportObjc
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

    let resolverDependencies: [DependencyViewModel]
    
    init?(_ dependencyContainer: DependencyContainer, dependencyGraph: DependencyGraph, depth: Int = 0) {

        guard let type = dependencyContainer.type, dependencyContainer.hasDependencies else {
            return nil
        }
        
        targetType = type
        embeddingTypes = dependencyContainer.embeddingTypes
        isRoot = dependencyContainer.isRoot
        isPublic = dependencyContainer.isPublic
        doesSupportObjc = dependencyContainer.doesSupportObjc
        injectableDependencies = dependencyContainer.injectableDependencies(dependencyGraph: dependencyGraph, depth: depth)

        references = dependencyContainer.allReferences.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
        registrations = dependencyContainer.registrations.orderedValues.map { RegistrationViewModel($0, dependencyGraph: dependencyGraph) }

        let directReferences = dependencyContainer.references.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph) }
        self.directReferences = directReferences
        let parameters = dependencyContainer.parameters.orderedValues.map { DependencyViewModel($0, dependencyGraph: dependencyGraph)}
        self.parameters = parameters
        
        resolverDependencies = directReferences + registrations.map { DependencyViewModel($0) }
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
        case .public,
             .open:
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
