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

    private let templateName: String
    
    public init(template name: String) {
        self.templateName = name
    }
    
    public func generate(from ast: Expr) throws -> String {

        let resolversData = [ResolverData](ast: ast)

        let path = Path("/usr/local/share/beaverdi/Resources")
        let fileLoader = FileSystemLoader(paths: [path])

        let environment = Environment(loader: fileLoader)
        let rendered = try environment.renderTemplate(name: "\(templateName).stencil", context: ["resolvers": resolversData])

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

