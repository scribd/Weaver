//
//  Stubs.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 11/21/19.
//

@testable import WeaverCodeGen
import Foundation

extension Dependency {
    
    static func stub(name: String, type: ConcreteType, at location: FileLocation) -> Dependency {
        return Dependency(kind: .registration,
                          dependencyName: name,
                          type: .concrete(type),
                          source: type,
                          fileLocation: location)
    }
}

extension DependencyContainer {
    
    static func stub(type: ConcreteType, at location: FileLocation?) -> DependencyContainer {
        return DependencyContainer(type: type, fileLocation: location, declarationSource: .type)
    }
}
