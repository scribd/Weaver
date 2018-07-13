//
//  Graph.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation

final class Graph {
    
    private var dependencyContainersByName = OrderedDictionary<String, DependencyContainer>()
    
    private var dependencyContainersByType = OrderedDictionary<String, DependencyContainer>()
    
    private var dependencyContainersByFile = OrderedDictionary<String, [DependencyContainer]>()
    
    private var typesByName = [String: [Type]]()
    
    private var importsByFile = [String: [String]]()
}

struct RegistrationIndex: AutoHashable, AutoEquatable {
    let name: String
    let type: Type
}

struct ReferenceIndex: AutoHashable, AutoEquatable {
    let name: String
}

final class DependencyContainer {

    let type: Type
    
    var registrations = [RegistrationIndex: Registration]()
    
    var references = [ReferenceIndex: Reference]()
    
    var sources = [DependencyContainer]()
    
    init(type: Type) {
        self.type = type
    }
}

final class Registration {
    
    let dependencyName: String
    
    let target: DependencyContainer
    
    let source: DependencyContainer
    
    init(dependencyName: String,
         target: DependencyContainer,
         source: DependencyContainer) {

        self.dependencyName = dependencyName
        self.target = target
        self.source = source
    }
}

final class Reference {
    
    let dependencyName: String
    
    let source: DependencyContainer
    
    init(dependencyName: String,
         source: DependencyContainer) {
        self.dependencyName = dependencyName
        self.source = source
    }
}

final class Parameter {
    
    let parameterName: String
    
    let source: DependencyContainer
    
    let type: Type
    
    init(parameterName: String,
         source: DependencyContainer,
         type: Type) {
        
        self.parameterName = parameterName
        self.source = source
        self.type = type
    }
}
