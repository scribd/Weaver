//
//  Generator.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import PathKit
import BeaverDI

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
            templateDirPath = Path("/usr/local/share/beaverdi")
        }
        
        buildResolvers(asts: asts)
        
        linkResolvers()
    }
    
    public func generate() throws -> [(file: String, data: String?)] {

        return try graph.resolversByFile.map { file, resolvers in

            guard !resolvers.isEmpty else {
                return (file: file, data: nil)
            }
            
            let fileLoader = FileSystemLoader(paths: [templateDirPath])
            let environment = Environment(loader: fileLoader)
            let context = ["resolvers": resolvers]
            
            let rendered = try environment.renderTemplate(name: templateName, context: context)
            
            return (file: file, data: rendered)
        }
    }
}

// MAKR: - Graph

private final class Graph {

    private(set) var resolversByType = [String: ResolverData]()

    var resolversByFile = [String: [ResolverData]]()
    
    func insert(_ resolver: ResolverData) {
        resolversByType[resolver.targetTypeName] = resolver
    }
}

// MARK: - Template Data

private final class RegisterData {
    let name: String
    let typeName: String
    let abstractTypeName: String
    let scope: String
    let isCustom: Bool
    var parameters: [VariableData] = []
    
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

private final class VariableData {
    let name: String
    let typeName: String
    var parameters: [VariableData] = []
    
    init(name: String,
         typeName: String) {
        self.name = name
        self.typeName = typeName
    }
}

private final class ResolverData {
    let targetTypeName: String
    let registrations: [RegisterData]
    let references: [VariableData]
    let parameters: [VariableData]
    let enclosingTypeNames: [String]?
    let isRoot: Bool
    
    init(targetTypeName: String,
         registrations: [RegisterData],
         references: [VariableData],
         parameters: [VariableData],
         enclosingTypeNames: [String]?,
         isRoot: Bool) {
        self.targetTypeName = targetTypeName
        self.registrations = registrations
        self.references = references
        self.parameters = parameters
        self.enclosingTypeNames = enclosingTypeNames
        self.isRoot = isRoot
    }
}

// MARK: - Conversion

extension RegisterData {
    
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

extension VariableData {
    
    convenience init(referenceAnnotation: ReferenceAnnotation) {
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName)
    }
    
    convenience init(registerAnnotation: RegisterAnnotation) {
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.protocolName ?? registerAnnotation.typeName)
    }
    
    convenience init(parameterAnnotation: ParameterAnnotation) {
        
        self.init(name: parameterAnnotation.name,
                  typeName: parameterAnnotation.typeName)
    }
}

// MARK: - Building

extension ResolverData {

    convenience init?(expr: Expr, enclosingTypeNames: [String]) {
        
        switch expr {
        case .typeDeclaration(let typeToken, children: let children):
            let targetTypeName = typeToken.value.name
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            var referenceAnnotations = [String: ReferenceAnnotation]()
            var customRefAnnotations = [String: CustomRefAnnotation]()
            var parameters = [VariableData]()
            
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
                    parameters.append(VariableData(parameterAnnotation: annotation.value))
                    
                case .file,
                     .typeDeclaration:
                    break
                }
            }
            
            let registrations = registerAnnotations.map {
                RegisterData(registerAnnotation: $0.value,
                             scopeAnnotation: scopeAnnotations[$0.key],
                             customRefAnnotation: customRefAnnotations[$0.key])
            } + referenceAnnotations.flatMap {
                if let customRefAnnotation = customRefAnnotations[$0.key] {
                    return RegisterData(referenceAnnotation: $0.value,
                                        scopeAnnotation: scopeAnnotations[$0.key],
                                        customRefAnnotation: customRefAnnotation)
                } else {
                    return nil
                }
            }

            let references = registerAnnotations.map {
                VariableData(registerAnnotation: $0.value)
            } + referenceAnnotations.map {
                VariableData(referenceAnnotation: $0.value)
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
                      isRoot: isRoot)
            
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
    
    private func buildResolvers(ast: Expr) -> (file: String, resolvers: [ResolverData])? {
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
    
    private func buildResolvers(exprs: [Expr], enclosingTypeNames: [String] = []) -> [ResolverData] {

        return exprs.flatMap { expr -> [ResolverData] in
            switch expr {
            case .typeDeclaration(let typeToken, let children):
                guard let resolverData = ResolverData(expr: expr, enclosingTypeNames: enclosingTypeNames) else {
                    return []
                }
                graph.insert(resolverData)
                let enclosingTypeNames = enclosingTypeNames + [typeToken.value.name]
                return [resolverData] + buildResolvers(exprs: children, enclosingTypeNames: enclosingTypeNames)
                
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
    
    func linkResolvers() {
        let resolvers = graph.resolversByFile.values.flatMap { $0 }
        let registrations = resolvers.flatMap { $0.registrations }
        let references = resolvers.flatMap { $0.references }

        for registration in registrations {
            registration.parameters = graph.resolversByType[registration.typeName]?.parameters ?? []
        }
        
        for reference in references {
            reference.parameters = graph.resolversByType[reference.typeName]?.parameters ?? []
        }
    }
}
