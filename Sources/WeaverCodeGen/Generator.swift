//
//  Generator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import PathKit
import Weaver

public final class Generator {

    private let templateDirPath: Path
    private let templateName: String
    
    private let graph = Graph()
    
    public init(asts: [Expr], template path: Path? = nil) throws {

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
        
        buildResolvers(asts: asts)
        
        link()
    }
    
    public func generate() throws -> [(file: String, data: String?)] {

        return try graph.resolversByFile.map { file, resolvers in

            guard !resolvers.isEmpty else {
                return (file: file, data: nil)
            }
            
            let fileLoader = FileSystemLoader(paths: [templateDirPath])
            let environment = Environment(loader: fileLoader)
            let context = ["resolvers": resolvers]
            let string = try environment.renderTemplate(name: templateName, context: context)
            
            return (file: file, data: string.compacted())
        }
    }
}

// MAKR: - Graph

private final class Graph {

    private(set) var resolversByType = [String: ResolverModel]()
    private(set) var typesByName = [String: [String]]()

    var resolversByFile = [String: [ResolverModel]]()
    
    func insertResolver(_ resolver: ResolverModel) {
        resolversByType[resolver.targetTypeName] = resolver
    }
    
    func insertVariable(_ variable: VariableModel) {
        var types = typesByName[variable.name] ?? []
        types.append(variable.typeName)
        variable.abstractTypeName.flatMap { types.append($0) }
        typesByName[variable.name] = types
    }
}

// MARK: - Template Model

private final class RegisterModel {
    let name: String
    let typeName: String
    let abstractTypeName: String
    let scope: String
    let isCustom: Bool
    var parameters: [VariableModel] = []
    var hasResolver: Bool = false
    
    init(name: String,
         typeName: String,
         abstractTypeName: String,
         scope: String,
         isCustom: Bool) {
        
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        self.scope = scope
        self.isCustom = isCustom
    }
}

private final class VariableModel {
    let name: String
    let typeName: String
    let abstractTypeName: String?

    var parameters: [VariableModel] = []
    let resolvedTypeName: String
    
    init(name: String,
         typeName: String,
         abstractTypeName: String?) {
        
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        resolvedTypeName = abstractTypeName ?? typeName
    }
}

private final class ResolverModel {
    let targetTypeName: String
    let registrations: [RegisterModel]
    let references: [VariableModel]
    let parameters: [VariableModel]
    let enclosingTypeNames: [String]?
    let isRoot: Bool
    let isPublic: Bool
    let doesSupportObjc: Bool
    let isIsolated: Bool
    
    init(targetTypeName: String,
         registrations: [RegisterModel],
         references: [VariableModel],
         parameters: [VariableModel],
         enclosingTypeNames: [String]?,
         isRoot: Bool,
         doesSupportObjc: Bool,
         accessLevel: AccessLevel,
         config: Set<ConfigurationAttribute>) {
        
        self.targetTypeName = targetTypeName
        self.registrations = registrations
        self.references = references
        self.parameters = parameters
        self.enclosingTypeNames = enclosingTypeNames
        self.isRoot = isRoot
        self.doesSupportObjc = doesSupportObjc
        
        switch accessLevel {
        case .`public`:
            isPublic = true
        case .`internal`:
            isPublic = false
        }
        
        isIsolated = config.isIsolated
    }
}

// MARK: - Conversion

extension RegisterModel {
    
    convenience init(registerAnnotation: RegisterAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     customRefAnnotation: CustomRefAnnotation?) {
       
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`

        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: registerAnnotation.protocolName ?? registerAnnotation.typeName,
                  scope: scope.stringValue,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue)
    }
    
    convenience init(referenceAnnotation: ReferenceAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     customRefAnnotation: CustomRefAnnotation?) {
        
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: referenceAnnotation.typeName,
                  scope: scope.stringValue,
                  isCustom: customRefAnnotation?.value ?? CustomRefAnnotation.defaultValue)
    }
}

extension VariableModel {
    
    convenience init(referenceAnnotation: ReferenceAnnotation) {
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName,
                  abstractTypeName: nil)
    }
    
    convenience init(registerAnnotation: RegisterAnnotation) {
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName,
                  abstractTypeName: registerAnnotation.protocolName)
    }
    
    convenience init(parameterAnnotation: ParameterAnnotation) {
        
        self.init(name: parameterAnnotation.name,
                  typeName: parameterAnnotation.typeName,
                  abstractTypeName: nil)
    }
}

// MARK: - Building

extension ResolverModel {

    convenience init?(expr: Expr, enclosingTypeNames: [String], graph: Graph) {
        
        switch expr {
        case .typeDeclaration(let typeToken, let configTokens, children: let children):
            let targetTypeName = typeToken.value.name
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            var referenceAnnotations = [String: ReferenceAnnotation]()
            var customRefAnnotations = [String: CustomRefAnnotation]()
            var parameters = [VariableModel]()
            
            for child in children {
                switch child {
                case .scopeAnnotation(let annotation):
                    scopeAnnotations[annotation.value.name] = annotation.value
                
                case .registerAnnotation(let annotation):
                    registerAnnotations[annotation.value.name] = annotation.value

                case .referenceAnnotation(let annotation):
                    referenceAnnotations[annotation.value.name] = annotation.value
                    
                case .customRefAnnotation(let annotation):
                    customRefAnnotations[annotation.value.name] = annotation.value
                    
                case .parameterAnnotation(let annotation):
                    parameters.append(VariableModel(parameterAnnotation: annotation.value))
                    
                case .file,
                     .typeDeclaration:
                    break
                }
            }
            
            let registrations = registerAnnotations.map {
                RegisterModel(registerAnnotation: $0.value,
                             scopeAnnotation: scopeAnnotations[$0.key],
                             customRefAnnotation: customRefAnnotations[$0.key])
            } + referenceAnnotations.flatMap {
                if let customRefAnnotation = customRefAnnotations[$0.key] {
                    return RegisterModel(referenceAnnotation: $0.value,
                                        scopeAnnotation: scopeAnnotations[$0.key],
                                        customRefAnnotation: customRefAnnotation)
                } else {
                    return nil
                }
            }

            let references = registerAnnotations.map { _, register -> VariableModel in
                let variable = VariableModel(registerAnnotation: register)
                graph.insertVariable(variable)
                return variable
            } + referenceAnnotations.map { _, reference -> VariableModel in
                let variable = VariableModel(referenceAnnotation: reference)
                graph.insertVariable(variable)
                return variable
            }
            
            let isRoot = referenceAnnotations.filter {
                let isCustom = customRefAnnotations[$0.key]?.value ?? CustomRefAnnotation.defaultValue
                return !isCustom
            }.isEmpty

            self.init(targetTypeName: targetTypeName,
                      registrations: registrations,
                      references: references,
                      parameters: parameters,
                      enclosingTypeNames: enclosingTypeNames,
                      isRoot: isRoot,
                      doesSupportObjc: typeToken.value.doesSupportObjc,
                      accessLevel: typeToken.value.accessLevel,
                      config: Set(configTokens.map { $0.value.attribute }))
            
        case .file,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .customRefAnnotation,
             .parameterAnnotation:
            return nil
        }
    }
}

private extension Generator {
    
    func buildResolvers(asts: [Expr]) {
        for ast in asts {
            if let (file, resolvers) = buildResolvers(ast: ast) {
                graph.resolversByFile[file] = resolvers
            }
        }
    }
    
    private func buildResolvers(ast: Expr) -> (file: String, resolvers: [ResolverModel])? {
        switch ast {
        case .file(let types, let name):
            let resolvers = buildResolvers(exprs: types)
            return (name, resolvers)
            
        case .typeDeclaration,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .customRefAnnotation,
             .parameterAnnotation:
            return nil
        }
    }
    
    private func buildResolvers(exprs: [Expr], enclosingTypeNames: [String] = []) -> [ResolverModel] {

        return exprs.flatMap { expr -> [ResolverModel] in
            switch expr {
            case .typeDeclaration(let typeToken, _, let children):
                guard let resolverModel = ResolverModel(expr: expr, enclosingTypeNames: enclosingTypeNames, graph: graph) else {
                    return []
                }
                graph.insertResolver(resolverModel)
                let enclosingTypeNames = enclosingTypeNames + [typeToken.value.name]
                return [resolverModel] + buildResolvers(exprs: children, enclosingTypeNames: enclosingTypeNames)
                
            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .scopeAnnotation,
                 .customRefAnnotation,
                 .parameterAnnotation:
                return []
            }
        }
    }
}

// MARK: - Linking

private extension Generator {
    
    func link() {
        
        let resolvers = graph.resolversByFile.values.flatMap { $0 }
        let registrations = resolvers.flatMap { $0.registrations }
        let references = resolvers.flatMap { $0.references }
        
        // link parameters to registrations
        for registration in registrations {
            registration.parameters = graph.resolversByType[registration.typeName]?.parameters ?? []
            registration.hasResolver = graph.resolversByType[registration.typeName] != nil
        }

        // link parameters to references
        for reference in references {
            reference.parameters = graph.resolversByType[reference.typeName]?.parameters ?? []
            
            if reference.parameters.isEmpty, let types = graph.typesByName[reference.name] {
                for type in types {
                    if let parameters = graph.resolversByType[type]?.parameters {
                        reference.parameters = parameters
                        break
                    }
                }
            }
        }
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
