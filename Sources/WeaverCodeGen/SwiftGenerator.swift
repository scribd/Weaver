//
//  SwiftGenerator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import PathKit
import Meta

public final class SwiftGenerator {
    
    private let dependencyGraph: DependencyGraph
    
    private let detailedResolvers: Bool
    
    private let version: String
    
    public init(dependencyGraph: DependencyGraph,
                detailedResolvers: Bool,
                version: String,
                mainTemplate mainTemplatePath: Path,
                detailedResolversTemplate detailedResolverTemplatePath: Path) throws {

        self.dependencyGraph = dependencyGraph
        self.detailedResolvers = detailedResolvers
        self.version = version
    }
    
    public func generate() throws -> [(file: String, data: String?)] {
        return []
    }
    
    public func generate() throws -> String? {
        return nil
    }
}
