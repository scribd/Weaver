//
//  Generator.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil
import PathKit

public final class Generator {

    private let templateDirPath: Path
    private let templateName: String
    
    public init(template path: Path? = nil) throws {
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
    }
    
    public func generate(from ast: Expr) throws -> String {

        let resolversData = [ResolverData](ast: ast)

        #if DEBUG
            let bundle = Bundle(for: type(of: self))
            let fileLoader = FileSystemLoader(bundle: [bundle])
        #else
            let fileLoader = FileSystemLoader(paths: [templateDirPath])
        #endif

        let environment = Environment(loader: fileLoader)
        let rendered = try environment.renderTemplate(name: templateName, context: ["resolvers": resolversData])

        return rendered
    }
}

// MARK: - Template Data

private struct DependencyData {
    let name: String
    let implementationTypeName: String
    let abstractTypeName: String
    let scope: String
}

private struct ResolverData {
    let targetTypeName: String
    let parentTypeName: String
    let dependencies: [DependencyData]
    let enclosingTypeNames: [String]?
}

// MARK: - Conversion

extension DependencyData {

    init(registerAnnotation: RegisterAnnotation,
         scopeAnnotation: ScopeAnnotation?) {
       
        let optionChars = CharacterSet(charactersIn: "?")

        self.init(name: registerAnnotation.name,
                  implementationTypeName: registerAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: registerAnnotation.protocolName ?? registerAnnotation.name,
                  scope: (scopeAnnotation?.scope ?? .graph).rawValue)
    }
}

extension ResolverData {

    init?(expr: Expr, enclosingTypeNames: [String]) {
        
        switch expr {
        case .typeDeclaration(let typeToken, parentResolver: let parentToken, children: let children):
            let targetTypeName = typeToken.value.name
            let parentTypeName = parentToken.value.typeName
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            
            for child in children {
                switch child {
                case .scopeAnnotation(let annotation):
                    scopeAnnotations[annotation.value.name] = annotation.value
                
                case .registerAnnotation(let annotation):
                    registerAnnotations[annotation.value.name] = annotation.value

                default:
                    break
                }
            }
            
            let dependencies = registerAnnotations.map {
                DependencyData(registerAnnotation: $0.value,
                               scopeAnnotation: scopeAnnotations[$0.key])
            }
            
            self.init(targetTypeName: targetTypeName,
                      parentTypeName: parentTypeName,
                      dependencies: dependencies,
                      enclosingTypeNames: enclosingTypeNames)
            
        case .registerAnnotation,
             .scopeAnnotation,
             .file:
            return nil
        }
    }
}

private extension Array where Element == ResolverData {
    
    init(exprs: [Expr], enclosingTypeNames: [String] = []) {

        self.init(exprs.flatMap { expr -> [ResolverData] in
            switch expr {
            case .typeDeclaration(let typeToken, _, let children):
                guard let resolverData = ResolverData(expr: expr, enclosingTypeNames: enclosingTypeNames) else {
                    return []
                }
                let enclosingTypeNames = enclosingTypeNames + [typeToken.value.name]
                return [resolverData] + [ResolverData](exprs: children, enclosingTypeNames: enclosingTypeNames)

            case .file,
                 .registerAnnotation,
                 .scopeAnnotation:
                return []
            }
        })
    }
    
    init(ast: Expr) {
        switch ast {
        case .file(let types):
            self.init(exprs: types)
        
        case .typeDeclaration:
            self.init(exprs: [ast])
            
        case .registerAnnotation,
             .scopeAnnotation:
            self.init()
        }
    }
}

