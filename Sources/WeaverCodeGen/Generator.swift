//
//  Generator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import PathKit
import WeaverDI

public final class Generator {
    
    private let graph: Graph

    private let templateDirPath: Path
    private let templateName: String
    
    public init(graph: Graph, template path: Path? = nil) throws {
        
        self.graph = graph

        if let path = path {
            var components = path.components
            guard let templateName = components.popLast() else {
                throw GeneratorError.invalidTemplatePath(path: path.description)
            }
            self.templateName = templateName
            templateDirPath = Path(components: components)
        } else {
            templateName = "Resources/dependency_resolver.stencil"
            templateDirPath = Path("/usr/local/share/weaver")
        }
    }
    
    public func generate() throws -> [(file: String, data: String?)] {

        return try graph.dependencyContainersByFile.orderedKeyValues.map { (file, dependencyContainers) in
            
            let dependencyContainers = dependencyContainers.compactMap { DependencyContainerViewModel($0, graph: graph) }

            guard !dependencyContainers.isEmpty else {
                return (file: file, data: nil)
            }
            
            let fileLoader = FileSystemLoader(paths: [templateDirPath])
            let environment = Environment(loader: fileLoader)
            
            let context: [String: Any] = ["resolvers": dependencyContainers,
                                          "imports": graph.importsByFile[file] ?? []]
            let string = try environment.renderTemplate(name: templateName, context: context)
            
            return (file: file, data: string.compacted())
        }
    }
}

// MARK: - Template Model

private struct RegistrationViewModel {
    
    let name: String
    let type: Type
    let abstractType: Type
    let scope: String
    let customRef: Bool
    let parameters: [DependencyViewModel]
    let hasBuilder: Bool
    
    init(_ dependency: Dependency, graph: Graph) {
        name = dependency.dependencyName
        type = dependency.type
        abstractType = dependency.abstractType
        
        let scope = dependency.scope ?? .default
        self.scope = scope.stringValue
                
        customRef = dependency.configuration.customRef
        
        if let dependencyContainer = graph.dependencyContainersByType[dependency.type.index] {
            parameters = dependencyContainer.parameters.map { DependencyViewModel($0, graph: graph) }
            hasBuilder = !dependencyContainer.parameters.isEmpty || !dependencyContainer.references.orderedKeys.isEmpty
        } else {
            parameters = []
            hasBuilder = false
        }
    }
}

private struct DependencyViewModel {

    let name: String
    let type: Type
    let abstractType: Type
    let isPublic: Bool
    let parameters: [DependencyViewModel]

    init(_ dependency: Dependency, graph: Graph) {
        
        name = dependency.dependencyName
        type = dependency.type
        abstractType = dependency.abstractType
        
        switch dependency {
        case is Registration:
            isPublic = false
        case is Reference,
             is Parameter:
            isPublic = true
        default:
            isPublic = false
        }

        let parameters = graph.dependencyContainersByType[dependency.type.index]?.parameters ?? []
        if parameters.isEmpty, let types = graph.typesByName[name] {
            var _parameters = [DependencyViewModel]()
            for type in types {
                if let parameters = graph.dependencyContainersByType[type.index]?.parameters {
                    _parameters = parameters.map { DependencyViewModel($0, graph: graph) }
                    break
                }
            }
            self.parameters = _parameters
        } else {
            self.parameters = parameters.map { DependencyViewModel($0, graph: graph) }
        }
    }
}

private struct DependencyContainerViewModel {

    let targetType: Type?
    let registrations: [RegistrationViewModel]
    let references: [DependencyViewModel]
    let parameters: [DependencyViewModel]
    let enclosingTypes: [Type]?
    let isRoot: Bool
    let isPublic: Bool
    let doesSupportObjc: Bool
    let isIsolated: Bool
    
    let publicReferences: [DependencyViewModel]
    let internalReferences: [DependencyViewModel]
    
    init?(_ dependencyContainer: DependencyContainer, graph: Graph) {

        guard let type = dependencyContainer.type, dependencyContainer.hasDependencies else {
            return nil
        }
        targetType = type
        registrations = dependencyContainer.registrations.orderedValues.map {
            RegistrationViewModel($0, graph: graph)
        }
        references = dependencyContainer.orderedDependencies.map {
            DependencyViewModel($0, graph: graph)
        }
        parameters = dependencyContainer.parameters.map {
            DependencyViewModel($0, graph: graph)
        }
        
        enclosingTypes = dependencyContainer.enclosingTypes
        
        let hasNonCustomReferences = dependencyContainer.references.orderedValues.contains {
            !$0.configuration.customRef
        }
        let hasParameters = !dependencyContainer.parameters.isEmpty
        isRoot = !hasNonCustomReferences && !hasParameters
        
        switch dependencyContainer.accessLevel {
        case .internal:
            isPublic = false
        case .public:
            isPublic = true
        }
        
        doesSupportObjc = dependencyContainer.doesSupportObjc
        isIsolated = dependencyContainer.configuration.isIsolated
        
        publicReferences = references.filter { $0.isPublic }
        internalReferences = references.filter { !$0.isPublic }
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
        return !registrations.orderedValues.isEmpty || !references.orderedValues.isEmpty || !parameters.isEmpty
    }
}

