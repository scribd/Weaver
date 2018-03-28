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
        
        let fileLoader = FileSystemLoader(paths: [templateDirPath])
        let environment = Environment(loader: fileLoader)
        let rendered = try environment.renderTemplate(name: templateName, context: ["resolvers": resolversData])

        return rendered
    }
}

// MARK: - Template Data

private struct RegisterData {
    let name: String
    let typeName: String
    let abstractTypeName: String
    let scope: String
}

private struct ReferenceData {
    let name: String
    let typeName: String
}

private struct ResolverData {
    let targetTypeName: String
    let registrations: [RegisterData]
    let references: [ReferenceData]
    let enclosingTypeNames: [String]?
    let isRoot: Bool
}

// MARK: - Conversion

extension RegisterData {
    
    init(registerAnnotation: RegisterAnnotation,
         scopeAnnotation: ScopeAnnotation?) {
       
        let optionChars = CharacterSet(charactersIn: "?")
        let scope = scopeAnnotation?.scope ?? .`default`

        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.typeName.trimmingCharacters(in: optionChars),
                  abstractTypeName: registerAnnotation.protocolName ?? registerAnnotation.typeName,
                  scope: scope.stringValue)
    }
}

extension ReferenceData {
    
    init(referenceAnnotation: ReferenceAnnotation) {
        
        self.init(name: referenceAnnotation.name,
                  typeName: referenceAnnotation.typeName)
    }
    
    init(registerAnnotation: RegisterAnnotation) {
        
        self.init(name: registerAnnotation.name,
                  typeName: registerAnnotation.protocolName ?? registerAnnotation.typeName)
    }
}

extension ResolverData {

    init?(expr: Expr, enclosingTypeNames: [String]) {
        
        switch expr {
        case .typeDeclaration(let typeToken, children: let children):
            let targetTypeName = typeToken.value.name
            
            var scopeAnnotations = [String: ScopeAnnotation]()
            var registerAnnotations = [String: RegisterAnnotation]()
            var referenceAnnotations = [String: ReferenceAnnotation]()
            
            for child in children {
                switch child {
                case .scopeAnnotation(let annotation):
                    scopeAnnotations[annotation.value.name] = annotation.value
                
                case .registerAnnotation(let annotation):
                    registerAnnotations[annotation.value.name] = annotation.value

                case .referenceAnnotation(let annotation):
                    referenceAnnotations[annotation.value.name] = annotation.value
                    
                case .file,
                     .typeDeclaration:
                    break
                }
            }
            
            let registrations = registerAnnotations.map {
                RegisterData(registerAnnotation: $0.value, scopeAnnotation: scopeAnnotations[$0.key])
            }

            let references = registerAnnotations.map {
                ReferenceData(registerAnnotation: $0.value)
            } + referenceAnnotations.map {
                ReferenceData(referenceAnnotation: $0.value)
            }
            
            let isRoot = referenceAnnotations.count == 0

            self.init(targetTypeName: targetTypeName,
                      registrations: registrations,
                      references: references,
                      enclosingTypeNames: enclosingTypeNames,
                      isRoot: isRoot)
            
        case .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation,
             .file:
            return nil
        }
    }
}

private extension Array where Element == ResolverData {
    
    init(exprs: [Expr], fileName: String, enclosingTypeNames: [String] = []) {

        self.init(exprs.flatMap { expr -> [ResolverData] in
            switch expr {
            case .typeDeclaration(let typeToken, let children):
                guard let resolverData = ResolverData(expr: expr, enclosingTypeNames: enclosingTypeNames) else {
                    return []
                }
                let enclosingTypeNames = enclosingTypeNames + [typeToken.value.name]
                return [resolverData] + [ResolverData](exprs: children, fileName: fileName, enclosingTypeNames: enclosingTypeNames)

            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .scopeAnnotation:
                return []
            }
        })
    }
    
    init(ast: Expr) {
        switch ast {
        case .file(let types, let name):
            self.init(exprs: types, fileName: name)
        
        case .typeDeclaration,
             .registerAnnotation,
             .scopeAnnotation,
             .referenceAnnotation:
            self.init()
        }
    }
}

