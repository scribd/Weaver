//
//  Graph.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation
import WeaverDI

public final class Graph {
    
    private(set) var dependencyContainersByName = OrderedDictionary<String, DependencyContainer>()
    
    private(set) var dependencyContainersByType = OrderedDictionary<TypeIndex, DependencyContainer>()
    
    private(set) var importsByFile = [String: [String]]()
    
    lazy var dependencyContainersByFile = dependencyContainersByType.orderedValues.reduce(OrderedDictionary<String, [DependencyContainer]>()) { (dependencyContainersByFile, dependencyContainer) in
        guard let file = dependencyContainer.fileLocation.file else {
            return dependencyContainersByFile
        }
        var dependencyContainersByFile = dependencyContainersByFile
        var dependencyContainers = dependencyContainersByFile[file] ?? []
        dependencyContainers.append(dependencyContainer)
        dependencyContainersByFile[file] = dependencyContainers
        return dependencyContainersByFile
    }

    lazy var dependencies: [ResolvableDependency] = {
        let allDependencies =
            dependencyContainersByName.orderedValues.flatMap { $0.orderedDependencies } +
            dependencyContainersByType.orderedValues.flatMap { $0.orderedDependencies }
        
        var filteredDependencies = Set<HashableDependency>()
        return allDependencies.filter {
            if filteredDependencies.contains(HashableDependency(value: $0)) {
                return false
            }
            filteredDependencies.insert(HashableDependency(value: $0))
            return true
        }
    }()
    
    lazy var typesByName = dependencies.reduce([String: [Type]]()) { (typesByName, dependency) in
        var typesByName = typesByName
        var types = typesByName[dependency.type.name] ?? []
        types.append(dependency.type)
        if dependency.type != dependency.abstractType {
            types.append(dependency.abstractType)
        }
        typesByName[dependency.type.name] = types
        return typesByName
    }
}

// MARK: - Write

extension Graph {
    
    func insertDependencyContainer(with registerAnnotation: TokenBox<RegisterAnnotation>,
                                   doesSupportObjc: Bool = false,
                                   file: String?) {

        let fileLocation = FileLocation(line: registerAnnotation.line, file: file)
        let dependencyContainer = DependencyContainer(type: registerAnnotation.value.type,
                                                      doesSupportObjc: doesSupportObjc,
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
    
    func insertImports(_ imports: [String], for file: String) {
        var fileImports = importsByFile[file] ?? []
        fileImports.append(contentsOf: imports)
        importsByFile[file] = fileImports
    }
}

// MARK: - Read

extension Graph {
    
    func dependencyContainer(type: Type,
                             accessLevel: AccessLevel,
                             doesSupportObjc: Bool,
                             fileLocation: FileLocation) -> DependencyContainer {
        
        if let dependencyContainer = dependencyContainersByType[type.index] {
            dependencyContainer.fileLocation = fileLocation
            dependencyContainer.accessLevel = accessLevel
            dependencyContainer.doesSupportObjc = doesSupportObjc
            dependencyContainer.type = type
            return dependencyContainer
        }
        
        let dependencyContainer = DependencyContainer(type: type,
                                                      accessLevel: accessLevel,
                                                      doesSupportObjc: doesSupportObjc,
                                                      fileLocation: fileLocation)
        dependencyContainersByType[type.index] = dependencyContainer
        return dependencyContainer
    }
    
    func registration(source: DependencyContainer,
                      registerAnnotation: TokenBox<RegisterAnnotation>,
                      scopeAnnotation: ScopeAnnotation?,
                      configuration: [TokenBox<ConfigurationAnnotation>],
                      file: String) throws -> Registration {
        
        let name = registerAnnotation.value.name
        guard let target = dependencyContainersByName[name] else {
            throw InspectorError.invalidGraph(registerAnnotation.printableDependency(file: file),
                                              underlyingError: .unresolvableDependency(history: []))
        }

        let configuration = DependencyConfiguration(with: configuration.map { $0.value.attribute })

        let fileLocation = FileLocation(line: registerAnnotation.line, file: file)
        let type = registerAnnotation.value.type
        return Registration(dependencyName: name,
                            type: type,
                            abstractType: registerAnnotation.value.protocolType ?? type,
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
                         type: referenceAnnotation.value.type,
                         target: target,
                         source: source,
                         configuration: configuration,
                         fileLocation: fileLocation)
    }
}

// MARK: - DependencyContainer

final class DependencyContainer: Hashable {

    var type: Type?
    
    var accessLevel: AccessLevel
    
    var doesSupportObjc: Bool
    
    var configuration: DependencyContainerConfiguration
    
    var registrations = OrderedDictionary<DependencyIndex, Registration>()
    
    var references = OrderedDictionary<DependencyIndex, Reference>()
    
    var parameters = [Parameter]()

    var sources = [DependencyContainer]()
    
    var referredTypes: Set<Type>
    
    var enclosingTypes: [Type] = []
    
    var fileLocation: FileLocation

    init(type: Type? = nil,
         accessLevel: AccessLevel = .default,
         doesSupportObjc: Bool = false,
         configuration: DependencyContainerConfiguration = .empty,
         referredType: Type? = nil,
         fileLocation: FileLocation = FileLocation()) {

        self.type = type
        self.accessLevel = accessLevel
        self.doesSupportObjc = doesSupportObjc
        self.configuration = configuration
        referredTypes = Set([referredType].compactMap { $0 })
        self.fileLocation = fileLocation
    }
    
    var orderedDependencies: [ResolvableDependency] {
        let orderedRegistrations: [ResolvableDependency] = registrations.orderedValues
        let orderedReferences: [ResolvableDependency] = references.orderedValues
        return orderedRegistrations + orderedReferences
    }
    
    func dependency(for index: DependencyIndex) -> ResolvableDependency? {
        return registrations[index] ?? references[index] ?? nil
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: DependencyContainer, rhs: DependencyContainer) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Dependency

protocol Dependency: AnyObject {
    
    var dependencyName: String { get }
    
    var type: Type { get }
    
    var abstractType: Type { get }
    
    var scope: Scope? { get }
    
    var configuration: DependencyConfiguration { get }
    
    var source: DependencyContainer { get }
    
    var fileLocation: FileLocation { get }
}

extension Dependency {
    
    var abstractType: Type {
        return type
    }
    
    var scope: Scope? {
        return nil
    }
    
    var configuration: DependencyConfiguration {
        return .empty
    }
}

protocol ResolvableDependency: Dependency {
    
    var target: DependencyContainer { get }
}

private struct HashableDependency: Hashable {
    
    let value: Dependency
    
    var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }
    
    static func ==(lhs: HashableDependency, rhs: HashableDependency) -> Bool {
        return ObjectIdentifier(lhs.value) == ObjectIdentifier(rhs.value)
    }
}

// MARK: - Registration

final class Registration: ResolvableDependency, Hashable {
    
    let dependencyName: String
    
    let type: Type
    
    let abstractType: Type
    
    let scope: Scope?
    
    var configuration: DependencyConfiguration
    
    let target: DependencyContainer
    
    let source: DependencyContainer
    
    let fileLocation: FileLocation
    
    init(dependencyName: String,
         type: Type,
         abstractType: Type,
         scope: Scope? = nil,
         configuration: DependencyConfiguration = .empty,
         target: DependencyContainer,
         source: DependencyContainer,
         fileLocation: FileLocation) {

        self.dependencyName = dependencyName
        self.type = type
        self.abstractType = abstractType
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

final class Reference: ResolvableDependency, Hashable {
    
    let dependencyName: String
    
    let type: Type
    
    let target: DependencyContainer
    
    let source: DependencyContainer
    
    let configuration: DependencyConfiguration
    
    let fileLocation: FileLocation
    
    init(dependencyName: String,
         type: Type,
         target: DependencyContainer,
         source: DependencyContainer,
         configuration: DependencyConfiguration,
         fileLocation: FileLocation) {
        self.dependencyName = dependencyName
        self.type = type
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

final class Parameter: Dependency {
    
    let parameterName: String
    
    var dependencyName: String {
        return parameterName
    }

    let source: DependencyContainer
    
    let type: Type
    
    let fileLocation: FileLocation
    
    init(parameterName: String,
         source: DependencyContainer,
         type: Type,
         fileLocation: FileLocation) {
        
        self.parameterName = parameterName
        self.source = source
        self.type = type
        self.fileLocation = fileLocation
    }
}

// MARK: - Indexes

struct DependencyIndex: AutoHashable, AutoEquatable {
    let name: String
    let type: Type?
}
