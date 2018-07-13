//
//  Graph.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation
import WeaverDI

final class Graph {
    
    private(set) var dependencyContainersByName = OrderedDictionary<String, DependencyContainer>()
    
    private(set) var dependencyContainersByType = OrderedDictionary<TypeIndex, DependencyContainer>()
    
    private(set) var dependencyContainersByFile = OrderedDictionary<String, [DependencyContainer]>()
    
    private(set) var typesByName = [String: [Type]]()
    
    private(set) var importsByFile = [String: [String]]()
}

// MARK: - Write

extension Graph {
    
    func insertDependencyContainer(with registerAnnotation: TokenBox<RegisterAnnotation>, file: String?) {

        let fileLocation = FileLocation(line: registerAnnotation.line, file: file)
        let dependencyContainer = DependencyContainer(type: registerAnnotation.value.type,
                                                      fileLocation: fileLocation)
        dependencyContainersByName[registerAnnotation.value.name] = dependencyContainer

        let type = registerAnnotation.value.type
        dependencyContainersByType[type.index] = dependencyContainer
    }
    
    func insertDependencyContainer(with referenceAnnotation: ReferenceAnnotation) {
        let name = referenceAnnotation.name
        let type = referenceAnnotation.type
        if let dependencyContainer = dependencyContainersByName[name] {
            dependencyContainer.referredTypes.insert(type)
            return
        }
        dependencyContainersByName[name] = DependencyContainer(referredType: type)
    }
}

// MARK: - Read

extension Graph {
    
    func dependencyContainer(type: Type,
                             accessLevel: AccessLevel,
                             fileLocation: FileLocation) -> DependencyContainer {
        
        if let dependencyContainer = dependencyContainersByType[type.index] {
            dependencyContainer.fileLocation = fileLocation
            dependencyContainer.accessLevel = accessLevel
            return dependencyContainer
        }
        
        let dependencyContainer = DependencyContainer(type: type,
                                                      accessLevel: accessLevel,
                                                      fileLocation: fileLocation)
        dependencyContainersByType[type.index] = dependencyContainer
        return dependencyContainer
    }
    
    func registration(source: DependencyContainer,
                      registerAnnotation: TokenBox<RegisterAnnotation>,
                      scopeAnnotation: ScopeAnnotation? = nil,
                      configuration: [TokenBox<ConfigurationAnnotation>],
                      file: String) throws -> Registration {
        
        let name = registerAnnotation.value.name
        guard let target = dependencyContainersByName[name] else {
            throw InspectorError.invalidGraph(registerAnnotation.printableDependency(file: file),
                                              underlyingError: .unresolvableDependency(history: []))
        }

        let configuration = DependencyConfiguration(with: configuration.map { $0.value.attribute })

        let fileLocation = FileLocation(line: registerAnnotation.line, file: file)
        
        return Registration(dependencyName: name,
                            scope: scopeAnnotation?.scope ?? .default,
                            configuration: configuration,
                            target: target,
                            source: source,
                            fileLocation: fileLocation)
    }
    
    func reference(source: DependencyContainer,
                   referenceAnnotation: TokenBox<ReferenceAnnotation>,
                   configuration: [TokenBox<ConfigurationAnnotation>],
                   file: String) throws -> Reference {
        
        let name = referenceAnnotation.value.name
        guard let target = dependencyContainersByName[name] else {
            throw InspectorError.invalidGraph(referenceAnnotation.printableDependency(file: file),
                                              underlyingError: .unresolvableDependency(history: []))

        }
        
        let configuration = DependencyConfiguration(with: configuration.map { $0.value.attribute })
        
        let fileLocation = FileLocation(line: referenceAnnotation.line, file: file)

        return Reference(dependencyName: name,
                         target: target,
                         source: source,
                         configuration: configuration,
                         fileLocation: fileLocation)
    }
}

// MARK: - DependencyContainer

final class DependencyContainer: Hashable {

    let type: Type?
    
    var accessLevel: AccessLevel
    
    var configuration: DependencyContainerConfiguration
    
    var registrations = [RegistrationIndex: Registration]()
    
    var references = [ReferenceIndex: Reference]()
    
    var sources = [DependencyContainer]()
    
    var referredTypes: Set<Type>
    
    var fileLocation: FileLocation

    init(type: Type? = nil,
         accessLevel: AccessLevel = .default,
         configuration: DependencyContainerConfiguration = .empty,
         referredType: Type? = nil,
         fileLocation: FileLocation = FileLocation()) {

        self.type = type
        self.accessLevel = accessLevel
        self.configuration = configuration
        referredTypes = Set([referredType].compactMap { $0 })
        self.fileLocation = fileLocation
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: DependencyContainer, rhs: DependencyContainer) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Registration

final class Registration: Hashable {
    
    let dependencyName: String
    
    let scope: Scope?
    
    var configuration: DependencyConfiguration

    let target: DependencyContainer
    
    let source: DependencyContainer
    
    let fileLocation: FileLocation
    
    init(dependencyName: String,
         scope: Scope? = nil,
         configuration: DependencyConfiguration = .empty,
         target: DependencyContainer,
         source: DependencyContainer,
         fileLocation: FileLocation) {

        self.dependencyName = dependencyName
        self.scope = scope
        self.configuration = configuration
        self.target = target
        self.source = source
        self.fileLocation = fileLocation
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Registration, rhs: Registration) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Reference

final class Reference: Hashable {
    
    let dependencyName: String
    
    let target: DependencyContainer
    
    let source: DependencyContainer
    
    let configuration: DependencyConfiguration
    
    let fileLocation: FileLocation
    
    init(dependencyName: String,
         target: DependencyContainer,
         source: DependencyContainer,
         configuration: DependencyConfiguration,
         fileLocation: FileLocation) {
        self.dependencyName = dependencyName
        self.target = target
        self.source = source
        self.configuration = configuration
        self.fileLocation = fileLocation
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Reference, rhs: Reference) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Parameter

final class Parameter: Hashable {
    
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
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Parameter, rhs: Parameter) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Indexes

struct RegistrationIndex: AutoHashable, AutoEquatable {
    let name: String
    let type: Type?
}

struct ReferenceIndex: AutoHashable, AutoEquatable {
    let name: String
    let type: Type?
}
