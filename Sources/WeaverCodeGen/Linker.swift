//
//  Linker.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation

public final class Linker {
    
    public let graph = Graph()

    public init(syntaxTrees: [Expr]) throws {
        try buildGraph(from: syntaxTrees)
    }
}

// MARK: - Build

private extension Linker {
    
    func buildGraph(from syntaxTrees: [Expr]) throws {
        collectDependencyContainers(from: syntaxTrees)
        try linkDependencyContainers(from: syntaxTrees)
    }
}

// MARK: - Collect

private extension Linker {

    func collectDependencyContainers(from syntaxTrees: [Expr]) {
        
        var file: String?
        
        // Insert dependency containers for which we know the type.
        for expr in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .file(_, let _file, _):
                file = _file

            case .registerAnnotation(let token):
                graph.insertDependencyContainer(with: token, file: file)

            case .typeDeclaration,
                 .scopeAnnotation,
                 .referenceAnnotation,
                 .parameterAnnotation,
                 .configurationAnnotation:
                break
            }
        }
        
        // Insert depndency containers for which we don't know the type
        for token in ExprSequence(exprs: syntaxTrees).referenceAnnotations {
            graph.insertDependencyContainer(with: token.value)
        }
    }
}

// MARK: - Link

private extension Linker {
    
    func linkDependencyContainers(from syntaxTrees: [Expr]) throws {
        
        for syntaxTree in syntaxTrees {
            if let file = syntaxTree.toFile() {
                try linkDependencyContainers(from: file.types, file: file.name)
            } else {
                throw InspectorError.invalidAST(.unknown, unexpectedExpr: syntaxTree)
            }
        }
    }
    
    func linkDependencyContainers(from exprs: [Expr], file: String) throws {

        for expr in exprs {
            guard let (token, children) = expr.toTypeDeclaration() else {
                throw InspectorError.invalidAST(.file(file), unexpectedExpr: expr)
            }
            
            let fileLocation = FileLocation(line: token.line, file: file)
            let dependencyContainer = graph.dependencyContainer(type: token.value.type,
                                                                accessLevel: token.value.accessLevel,
                                                                doesSupportObjc: token.value.doesSupportObjc,
                                                                fileLocation: fileLocation)

            try linkDependencyContainer(dependencyContainer,
                                        with: children,
                                        file: file)
        }
    }
    
    func linkDependencyContainer(_ dependencyContainer: DependencyContainer,
                                 with children: [Expr],
                                 enclosingTypes: [Type] = [],
                                 file: String) throws {

        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var referenceAnnotations: [TokenBox<ReferenceAnnotation>] = []
        var scopeAnnotations: [String: ScopeAnnotation] = [:]
        var configurationAnnotations: [ConfigurationAttributeTarget: [TokenBox<ConfigurationAnnotation>]] = [:]
        var parameters = [Parameter]()

        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, let children):
                let fileLocation = FileLocation(line: injectableType.line, file: file)
                let childDependencyContainer = graph.dependencyContainer(type: injectableType.value.type,
                                                                         accessLevel: injectableType.value.accessLevel,
                                                                         doesSupportObjc: injectableType.value.doesSupportObjc,
                                                                         fileLocation: fileLocation)
                try linkDependencyContainer(childDependencyContainer,
                                            with: children,
                                            enclosingTypes: enclosingTypes + [injectableType.value.type],
                                            file: file)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .referenceAnnotation(let referenceAnnotation):
                referenceAnnotations.append(referenceAnnotation)
                
            case .scopeAnnotation(let scopeAnnotation):
                scopeAnnotations[scopeAnnotation.value.name] = scopeAnnotation.value
                
            case .configurationAnnotation(let configurationAnnotation):
                let target = configurationAnnotation.value.target
                configurationAnnotations[target] = (configurationAnnotations[target] ?? []) + [configurationAnnotation]
                
            case .parameterAnnotation(let parameterAnnotation):
                let parameter = Parameter(parameterName: parameterAnnotation.value.name,
                                          source: dependencyContainer,
                                          type: parameterAnnotation.value.type,
                                          fileLocation: FileLocation(line: parameterAnnotation.line, file: file))
                parameters.append(parameter)
                
            case .file:
                break
            }
        }

        dependencyContainer.configuration = DependencyContainerConfiguration(
            with: configurationAnnotations[.`self`]?.map { $0.value }
        )
        
        dependencyContainer.enclosingTypes = enclosingTypes
        
        for registerAnnotation in registerAnnotations {
            let name = registerAnnotation.value.name
            let registration = try graph.registration(source: dependencyContainer,
                                                      registerAnnotation: registerAnnotation,
                                                      scopeAnnotation: scopeAnnotations[name],
                                                      configuration: configurationAnnotations[.dependency(name: name)] ?? [],
                                                      file: file)
            let index = DependencyIndex(name: name, type: registration.target.type)
            dependencyContainer.registrations[index] = registration
            registration.target.sources.append(dependencyContainer)
        }
        
        for referenceAnnotation in referenceAnnotations {
            let name = referenceAnnotation.value.name
            let reference = try graph.reference(source: dependencyContainer,
                                                referenceAnnotation: referenceAnnotation,
                                                configuration: configurationAnnotations[.dependency(name: name)] ?? [],
                                                file: file)
            let index = DependencyIndex(name: name, type: reference.target.type)
            dependencyContainer.references[index] = reference
            reference.target.sources.append(dependencyContainer)
        }
    }
}
