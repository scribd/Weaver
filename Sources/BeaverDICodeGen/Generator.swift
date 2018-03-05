//
//  Generator.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import Stencil

struct DependencyData {
    let name: String
    let implementationTypeName: String
    let protocolName: String
    let scope: String
}

struct ResolverData {
    let targetTypeName: String
    let parentTypeName: String
    
    let dependencies: [DependencyData]
}

final class Generator {

    private let templateName: String
    
    init(template name: String) {
        self.templateName = name
    }
    
    func generate<IN: DataInput>(in output: IN, resolver: ResolverData) throws {

        let environment = Environment(loader: FileSystemLoader(bundle: [Bundle(for: type(of: self))]))
        let rendered = try environment.renderTemplate(name: "Resources/\(templateName).stencil", context: ["resolver": resolver, "dependencies": resolver.dependencies])

        output += rendered
    }
}

