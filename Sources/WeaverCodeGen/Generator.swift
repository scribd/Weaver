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
            let context: [String: Any] = ["resolvers": resolvers,
                                          "imports": graph.importsByFile[file] ?? []]
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
    var importsByFile = [String: [String]]()
    
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
    let customRef: Bool
    var parameters: [VariableModel] = []
    var hasBuilder: Bool = false
    
    init(name: String,
         typeName: String,
         abstractTypeName: String,
         scope: String,
         config: DependencyConfiguration) {
        
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        self.scope = scope
        customRef = config.customRef
    }
}

private enum VariableModelType {
    case registration
    case reference
    case parameter
}

private final class VariableModel {
    let name: String
    let typeName: String
    let abstractTypeName: String?

    var parameters: [VariableModel] = []
    let resolvedTypeName: String
    let type: VariableModelType
    
    let isPublic: Bool
    
    init(name: String,
         typeName: String,
         abstractTypeName: String?,
         type: VariableModelType,
         accessLevel: AccessLevel) {
        
        self.name = name
        self.typeName = typeName
        self.abstractTypeName = abstractTypeName
        self.type = type
        
        switch accessLevel {
        case .internal:
            isPublic = false
        case .public:
            isPublic = true
        }
        
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
    
    let publicReferences: [VariableModel]
    let internalReferences: [VariableModel]
    
    init(targetTypeName: String,
         registrations: [RegisterModel],
         references: [VariableModel],
         parameters: [VariableModel],
         enclosingTypeNames: [String]?,
         isRoot: Bool,
         doesSupportObjc: Bool,
         accessLevel: AccessLevel,
         config: ResolverConfiguration) {
        
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
        
        self.isIsolated = config.isIsolated
        
        publicReferences = references.filter { $0.isPublic }
        internalReferences = references.filter { !$0.isPublic }
    }
}

// MARK: - Conversion

extension RegisterModel {
    
    convenience init(registerAnnotation: RegisterAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     configurationAnnotations: [ConfigurationAnnotation]) {
       
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`
        let config = DependencyConfiguration(with: configurationAnnotations)
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: registerAnnotation.protocolName ?? registerAnnotation.typeName,
                  scope: scope.stringValue,
                  config: config)
    }
    
    convenience init(referenceAnnotation: ReferenceAnnotation,
                     scopeAnnotation: ScopeAnnotation?,
                     configurationAnnotations: [ConfigurationAnnotation]) {
        
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`
        let config = DependencyConfiguration(with: configurationAnnotations)

        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: referenceAnnotation.typeName,
                  scope: scope.stringValue,
                  config: config)
    }
}

extension VariableModel {
    
    convenience init(referenceAnnotation: ReferenceAnnotation) {
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName,
                  abstractTypeName: nil,
                  type: .reference,
                  accessLevel: .public)
    }
    
    convenience init(registerAnnotation: RegisterAnnotation) {
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName,
                  abstractTypeName: registerAnnotation.protocolName,
                  type: .registration,
                  accessLevel: .internal)
    }
    
    convenience init(parameterAnnotation: ParameterAnnotation) {
        
        self.init(name: parameterAnnotation.name,
                  typeName: parameterAnnotation.typeName,
                  abstractTypeName: nil,
                  type: .parameter,
                  accessLevel: .public)
    }
}

// MARK: - Building

extension ResolverModel {

    convenience init?(expr: Expr, enclosingTypeNames: [String], graph: Graph) {
        
        switch expr {
        case .typeDeclaration(let typeToken, children: let children):
            let targetTypeName = typeToken.value.name
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            var referenceAnnotations = [String: ReferenceAnnotation]()
            var configurationAnnotations = [ConfigurationAttributeTarget: [ConfigurationAnnotation]]()
            var parameters = [VariableModel]()
            
            for child in children {
                switch child {
                case .scopeAnnotation(let annotation):
                    scopeAnnotations[annotation.value.name] = annotation.value
                
                case .registerAnnotation(let annotation):
                    registerAnnotations[annotation.value.name] = annotation.value

                case .referenceAnnotation(let annotation):
                    referenceAnnotations[annotation.value.name] = annotation.value
                    
                case .parameterAnnotation(let annotation):
                    parameters.append(VariableModel(parameterAnnotation: annotation.value))
                    
                case .configurationAnnotation(let annotation):
                    let target = annotation.value.target
                    configurationAnnotations[target] = (configurationAnnotations[target] ?? []) + [annotation.value]
                                        
                case .file,
                     .typeDeclaration:
                    break
                }
            }
            
            let registrations = registerAnnotations.map {
                RegisterModel(registerAnnotation: $0.value,
                              scopeAnnotation: scopeAnnotations[$0.key],
                              configurationAnnotations: configurationAnnotations[.dependency(name: $0.value.name)] ?? [])
            } + referenceAnnotations.map {
                RegisterModel(referenceAnnotation: $0.value,
                              scopeAnnotation: scopeAnnotations[$0.key],
                              configurationAnnotations: configurationAnnotations[.dependency(name: $0.value.name)] ?? [])
            }.filter { $0.customRef }

            let references =
                registerAnnotations.map { VariableModel(registerAnnotation: $1) } +
                referenceAnnotations.compactMap { VariableModel(referenceAnnotation: $1) }
            
            references.forEach(graph.insertVariable)
            
            let isRoot = referenceAnnotations.filter {
                let configurationAnnotations = configurationAnnotations[.dependency(name: $0.value.name)]
                let config = DependencyConfiguration(with: configurationAnnotations)
                return !config.customRef
            }.isEmpty
            
            let config = ResolverConfiguration(with: configurationAnnotations[.`self`])

            self.init(targetTypeName: targetTypeName,
                      registrations: registrations,
                      references: references,
                      parameters: parameters,
                      enclosingTypeNames: enclosingTypeNames,
                      isRoot: isRoot,
                      doesSupportObjc: typeToken.value.doesSupportObjc,
                      accessLevel: typeToken.value.accessLevel,
                      config: config)
            
        case .file,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .parameterAnnotation,
             .configurationAnnotation:
            return nil
        }
    }
}

private extension Generator {
    
    func buildResolvers(asts: [Expr]) {
        for ast in asts {
            if let (file, imports, resolvers) = buildResolvers(ast: ast) {
                graph.resolversByFile[file] = resolvers
                graph.importsByFile[file] = imports
            }
        }
    }
    
    private func buildResolvers(ast: Expr) -> (file: String, imports: [String], resolvers: [ResolverModel])? {
        guard let file = ast.toFile() else {
            return nil
        }
        let resolvers = buildResolvers(exprs: file.types)
        return (file.name, file.imports, resolvers)
    }
    
    private func buildResolvers(exprs: [Expr], enclosingTypeNames: [String] = []) -> [ResolverModel] {

        return exprs.flatMap { expr -> [ResolverModel] in
            guard let (token, children) = expr.toTypeDeclaration(),
                  let resolverModel = ResolverModel(expr: expr,
                                                    enclosingTypeNames: enclosingTypeNames,
                                                    graph: graph) else {
                return []
            }
            graph.insertResolver(resolverModel)
            let enclosingTypeNames = enclosingTypeNames + [token.value.name]
            return [resolverModel] + buildResolvers(exprs: children, enclosingTypeNames: enclosingTypeNames)
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
            if let resolver = graph.resolversByType[registration.typeName] {
                registration.parameters = resolver.parameters
                registration.hasBuilder = !resolver.parameters.isEmpty || !resolver.references.filter { $0.type == .reference }.isEmpty
            } else {
                registration.parameters = []
                registration.hasBuilder = false
            }
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
