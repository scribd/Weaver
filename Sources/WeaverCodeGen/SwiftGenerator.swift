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
                version: String) throws {

        self.dependencyGraph = dependencyGraph
        self.detailedResolvers = detailedResolvers
        self.version = version
    }
    
    public func generate() throws -> [(file: String, data: String?)] {
        
        return try dependencyGraph.dependencyContainersByFile.orderedKeys.lazy.map {
            MetaWeaverFile(fileName: $0, dependencyGraph: self.dependencyGraph)
        }.compactMap {
            guard let swiftString = try $0.meta()?.swiftString else { return nil }
            return ($0.fileName, swiftString)
        }
    }
    
    public func generate() throws -> String? {
        
        guard dependencyGraph.dependencyContainersByFile.orderedKeys.isEmpty == false else {
            return nil
        }
        
        let files = dependencyGraph.dependencyContainersByFile.orderedKeys.lazy.map {
            MetaWeaverFile(fileName: $0, dependencyGraph: self.dependencyGraph)
        }

        return Meta.File(name: "Weaver.swift")
            .adding(imports: files.flatMap { $0.imports })
            .adding(members: Array(try files.compactMap { try $0.meta() }.joined(separator: [EmptyLine()])))
            .swiftString
    }
}

// MARK: - Meta

private struct MetaWeaverFile {
    
    let fileName: String
    
    let dependencyGraph: DependencyGraph
    
    func meta() throws -> Meta.File? {
        
        guard let fileBodyMembers: [FileBodyMember] = try meta() else {
            return nil
        }
        
        return File(name: fileName)
            .adding(imports: imports)
            .adding(members: fileBodyMembers)
    }
    
    var imports: [Import] {
        return dependencyGraph.importsByFile[fileName]?.map { Import(name: $0) } ?? []
    }
    
    func meta() throws -> [FileBodyMember]? {

        let dependencyContainers = try dependencyGraph.dependencyContainers(forFileName: fileName)

        guard dependencyContainers.isEmpty == false else {
            return nil
        }

        return Array(
            try dependencyContainers
                .map { try MetaDependencyContainer(dependencyContainer: $0).meta() }
                .joined(separator: [EmptyLine()])
        )
    }
}

private struct MetaDependencyContainer {
    
    let dependencyContainer: DependencyContainer
    
    func meta() throws -> [FileBodyMember] {
        return []
    }
}

// MARK: - Utils

private extension DependencyGraph {
    
    func dependencyContainers(forFileName fileName: String) throws -> [DependencyContainer] {
        guard let dependencyContainers = dependencyContainersByFile[fileName] else {
            throw SwiftGeneratorError.dependencyContainersNotFoundForFileName(fileName)
        }
        return dependencyContainers
    }
}
