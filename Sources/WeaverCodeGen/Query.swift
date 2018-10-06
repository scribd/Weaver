//
//  Query.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 10/6/18.
//

import Foundation

public final class Query {
    
    private let graph: DependencyGraph
    
    public init(_ graph: DependencyGraph) {
        self.graph = graph
    }
    
    public func information(forDependency name: String) -> DependencyContainer? {
        return graph.dependencyContainersByName[name]
    }
}
