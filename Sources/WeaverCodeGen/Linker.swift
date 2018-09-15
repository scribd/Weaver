//
//  Linker.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation

// MARK: - DependencyContainer

/**
 
    Object representing the dependency container associated to an injectable type.

    Dependency containers are linked together through `Registration`s, `Reference`s and
    source dependency containers.

    For example, the following code:

    ```
    final class Foo {
        // weaver: boo <- Boo
        // weaver: doo = Doo
    }
    ```

    Produces the following graph:

    `FooDependencyContainer` -- reference --> `BooDependencyContainer`
                           |- registration -> `DooDependencyContainer`

    `DooDependencyContainer` -- source --> `FooDependencyContainer`
 
*/
final class DependencyContainer: Hashable {

    /// Type representation of the associated type.
    fileprivate(set) var type: Type?
    
    /// Access level representation of the associated type.
    fileprivate(set) var accessLevel: AccessLevel
    
    /// True if the associated type is prefixed with `@objc` keyword.
    fileprivate(set) var doesSupportObjc: Bool

    /// Configuration built based on the configuration annotations.
    fileprivate(set) var configuration: DependencyContainerConfiguration
    
    /// Registrations grouped by name & type and iterable in order of appearance in the source code.
    fileprivate(set) var registrations = OrderedDictionary<DependencyIndex, ResolvableDependency>()

    /// References grouped by name & type and iterable in order of appearance in the source code.
    fileprivate(set) var references = OrderedDictionary<DependencyIndex, ResolvableDependency>()
    
    /// Parameters listed in order of appearance in the source code.
    fileprivate(set) var parameters = [Dependency]()
    
    /// Dependency containers from which this dependency container's associated type is being registered.
    fileprivate(set) var sources = [DependencyContainer]()

    /// Types referenced by this dependency container.
    fileprivate(set) var referencedTypes: Set<Type>
    
    /**
     Types in which the dependency container's associated type is embedded.
     
     For example:
     
     ```
     final class Foo {
         final class Boo {
             // weaver: doo <- Doo
         }
     }
     ```
     
     Produces a dependency container with one embedding type: `Foo`.
    */
    fileprivate(set) var embeddingTypes: [Type] = []
    
    /// Location of the associated type declaration in the source code file.
    fileprivate(set) var fileLocation: FileLocation
    
    fileprivate init(type: Type? = nil,
                     accessLevel: AccessLevel = .default,
                     doesSupportObjc: Bool = false,
                     configuration: DependencyContainerConfiguration = .empty,
                     referencedType: Type? = nil,
                     fileLocation: FileLocation = FileLocation()) {
        
        self.type = type
        self.accessLevel = accessLevel
        self.doesSupportObjc = doesSupportObjc
        self.configuration = configuration
        referencedTypes = Set([referencedType].compactMap { $0 })
        self.fileLocation = fileLocation
    }
    
    /// All the resolvable dependencies in order of appearance in the source code.
    var orderedDependencies: [ResolvableDependency] {
        let orderedRegistrations: [ResolvableDependency] = registrations.orderedValues
        let orderedReferences: [ResolvableDependency] = references.orderedValues
        return orderedRegistrations + orderedReferences
    }
    
    /// Returns the resolvable dependency for an index, looking first through the registrations,
    /// then references.
    ///
    /// - Parameter index: Index of the resolvable dependency to look for.
    ///
    /// - Returns: The found resolvable dependency.
    func dependency(for index: DependencyIndex) -> ResolvableDependency? {
        return registrations[index] ?? references[index] ?? nil
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: DependencyContainer, rhs: DependencyContainer) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Dependency

/**
    Representation of any kind of dependencies.

    # A dependency can be one of the following:
    - Registration
    - Reference
    - Parameter

    For example the following code:

    ```
    final class Foo {
        // weaver: boo = Boo <- BooProtocol
        // weaver: boo.scope = .transient
    }
    ```

    Produces a dependency of type `Registration` with:
    - `dependencyName` = "boo"
    - `type` = `Boo`
    - `abstractType` = `BooProtocol`
    - `scope` = .transient
    - `source` = `FooDependencyContainer`
 */
protocol Dependency: AnyObject {

    /// Name which was used to declare the dependency.
    var dependencyName: String { get }

    /// Type which was used to declare the dependency.
    var type: Type { get }
    
    /// Abstract type which was used to declare the dependency.
    ///
    /// - Note: Usually a `protocol`, but can also be any parent class.
    var abstractType: Type { get }
    
    /// Scope declared with a scope annotation associated to the same dependency name.
    ///
    /// - Note: `nil` if the dependency is a reference or a parameter.
    var scope: Scope? { get }
    
    /// Configuration built based on the configuration annotations
    /// associated to the same dependency name.
    var configuration: DependencyConfiguration { get }

    /// Dependency container which contains the dependency.
    var source: DependencyContainer { get }
    
    /// Location of the declarative annotation in the source code.
    var fileLocation: FileLocation { get }
}

extension Dependency {
    
    var abstractType: Type {
        return type
    }
    
    var scope: Scope? {
        return !isReference ? configuration.scope : nil
    }
    
    var configuration: DependencyConfiguration {
        return .empty
    }
    
    var isReference: Bool {
        return self is Reference
    }
}

/**
    Representation of any kind of dependencies which can be resolved through a
    hierarchy of dependency containers.

    # A dependency can be one of the following:
    - Registration
    - Reference

    For example the following code:

    ```
    final class Foo {
        // weaver: boo = Boo
    }
    ```

    Produces a dependency of type `Registration` with `BooDependencyContainer` as a target.
 */
protocol ResolvableDependency: Dependency {
    
    /// Dependency container associated to the same type.
    var target: DependencyContainer { get }
}

private struct HashableDependency: Hashable {
    
    let value: Dependency
    
    var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }
    
    static func ==(lhs: HashableDependency, rhs: HashableDependency) -> Bool {
        return lhs.value === rhs.value
    }
}

// MARK: - Registration

fileprivate final class Registration: ResolvableDependency, Hashable {
    
    let dependencyName: String
    
    let type: Type
    
    let abstractType: Type
    
    var configuration: DependencyConfiguration
    
    let target: DependencyContainer
    
    let source: DependencyContainer
    
    let fileLocation: FileLocation
    
    init(dependencyName: String,
         type: Type,
         abstractType: Type,
         configuration: DependencyConfiguration = .empty,
         target: DependencyContainer,
         source: DependencyContainer,
         fileLocation: FileLocation) {
        
        self.dependencyName = dependencyName
        self.type = type
        self.abstractType = abstractType
        self.configuration = configuration
        self.target = target
        self.source = source
        self.fileLocation = fileLocation
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    static func ==(lhs: Registration, rhs: Registration) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Reference

fileprivate final class Reference: ResolvableDependency, Hashable {
    
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
        return lhs === rhs
    }
}

// MARK: - Parameter

fileprivate final class Parameter: Dependency {
    
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

/// Object in charge of going through the AST for each file, and link dependency containers
/// together to produce the dependency graph.
public final class Linker {

    /// Produced dependency graph
    public let dependencyGraph = DependencyGraph()

    /// - Parameter syntaxTrees: list of syntax trees (AST) for each source file.
    ///
    /// - Throws:
    ///     - `InspectorError.invalidDependencyGraph` // TODO: Create a specific error type for the linker.
    public init(syntaxTrees: [Expr]) throws {
        try buildDependencyGraph(from: syntaxTrees)
    }
}

// MARK: - Graph

/// Representation of the dependency graph.
///
/// - Note: Indexes the dependency containers and dependencies.
public final class DependencyGraph {
    
    /// `DependencyContainer`s grouped by name and iterable in order of appearance in the source code.
    private(set) var dependencyContainersByName = OrderedDictionary<String, DependencyContainer>()
    
    /// `DependencyContainer`s grouped by type and iterable in order of appearance in the source code.
    private(set) var dependencyContainersByType = OrderedDictionary<TypeIndex, DependencyContainer>()
    
    /// Imported module names grouped by file name.
    private(set) var importsByFile = [String: [String]]()
    
    /// `DependencyContainer`s grouped by file name and iterable in order of appearance in the source code.
    lazy var dependencyContainersByFile: OrderedDictionary<String, [DependencyContainer]> = {
        return dependencyContainersByType.orderedValues.reduce(OrderedDictionary()) { (dependencyContainersByFile, dependencyContainer) in
            guard let file = dependencyContainer.fileLocation.file else {
                return dependencyContainersByFile
            }
            var dependencyContainersByFile = dependencyContainersByFile
            var dependencyContainers = dependencyContainersByFile[file] ?? []
            dependencyContainers.append(dependencyContainer)
            dependencyContainersByFile[file] = dependencyContainers
            return dependencyContainersByFile
        }
    }()
    
    /// All the dependencies in order of appearance in the source code.
    lazy var dependencies: [ResolvableDependency] = {
        let allDependencies = dependencyContainersByName.orderedValues.flatMap { $0.orderedDependencies } +
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
    
    /// Types grouped by type name.
    lazy var typesByName: [String: [Type]] = {
        return dependencies.reduce([:]) { (typesByName, dependency) in
            var typesByName = typesByName
            var types = typesByName[dependency.type.name] ?? []
            types.append(dependency.type)
            if dependency.type != dependency.abstractType {
                types.append(dependency.abstractType)
            }
            typesByName[dependency.type.name] = types
            return typesByName
        }
    }()
}

// MARK: - Insertions

private extension DependencyGraph {
    
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
            dependencyContainer.referencedTypes.insert(type)
            return
        }
        dependencyContainersByName[name] = DependencyContainer(referencedType: type)
    }
    
    func insertImports(_ imports: [String], for file: String) {
        var fileImports = importsByFile[file] ?? []
        fileImports.append(contentsOf: imports)
        importsByFile[file] = fileImports
    }
}

// MARK: - LazyLoading

private extension DependencyGraph {
    
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
                      configuration: [TokenBox<ConfigurationAnnotation>],
                      file: String) throws -> Registration {
        
        let name = registerAnnotation.value.name
        guard let target = dependencyContainersByName[name] else {
            throw InspectorError.invalidDependencyGraph(registerAnnotation.printableDependency(file: file),
                                                        underlyingError: .unresolvableDependency(history: []))
        }
        
        let configuration = DependencyConfiguration(with: configuration.map { $0.value.attribute })
        
        let fileLocation = FileLocation(line: registerAnnotation.line, file: file)
        let type = registerAnnotation.value.type
        return Registration(dependencyName: name,
                            type: type,
                            abstractType: registerAnnotation.value.protocolType ?? type,
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
            throw InspectorError.invalidDependencyGraph(referenceAnnotation.printableDependency(file: file),
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

// MARK: - Build

private extension Linker {
    
    func buildDependencyGraph(from syntaxTrees: [Expr]) throws {
        collectDependencyContainers(from: syntaxTrees)
        try linkDependencyContainers(from: syntaxTrees)
    }
}

// MARK: - Collect

private extension Linker {
    
    func collectDependencyContainers(from syntaxTrees: [Expr]) {
        
        var file: String?
        
        // Insert dependency containers for which we know the type.
        for expr in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .file(_, let _file, let imports):
                file = _file
                dependencyGraph.insertImports(imports, for: _file)
                
            case .registerAnnotation(let token):
                dependencyGraph.insertDependencyContainer(with: token, file: file)
                
            case .typeDeclaration,
                 .referenceAnnotation,
                 .parameterAnnotation,
                 .configurationAnnotation:
                break
            }
        }
        
        // Insert depndency containers for which we don't know the type
        for token in ExprSequence(exprs: syntaxTrees).referenceAnnotations {
            dependencyGraph.insertDependencyContainer(with: token.value)
        }
    }
}

// MARK: - Link

private extension Linker {
    
    func linkDependencyContainers(from syntaxTrees: [Expr]) throws {
        
        for syntaxTree in syntaxTrees {
            if let file = syntaxTree.toFile() {
                try linkDependencyContainers(from: file.types, file: file.name)
            } else {
                throw InspectorError.invalidAST(.unknown, unexpectedExpr: syntaxTree)
            }
        }
    }
    
    func linkDependencyContainers(from exprs: [Expr], file: String) throws {
        
        for expr in exprs {
            guard let (token, children) = expr.toTypeDeclaration() else {
                throw InspectorError.invalidAST(.file(file), unexpectedExpr: expr)
            }
            
            let fileLocation = FileLocation(line: token.line, file: file)
            let dependencyContainer = dependencyGraph.dependencyContainer(type: token.value.type,
                                                                          accessLevel: token.value.accessLevel,
                                                                          doesSupportObjc: token.value.doesSupportObjc,
                                                                          fileLocation: fileLocation)
            
            try linkDependencyContainer(dependencyContainer,
                                        with: children,
                                        file: file)
        }
    }
    
    func linkDependencyContainer(_ dependencyContainer: DependencyContainer,
                                 with children: [Expr],
                                 embeddingTypes: [Type] = [],
                                 file: String) throws {
        
        var registerAnnotations: [TokenBox<RegisterAnnotation>] = []
        var referenceAnnotations: [TokenBox<ReferenceAnnotation>] = []
        var configurationAnnotations: [ConfigurationAttributeTarget: [TokenBox<ConfigurationAnnotation>]] = [:]
        
        for child in children {
            switch child {
            case .typeDeclaration(let injectableType, let children):
                let fileLocation = FileLocation(line: injectableType.line, file: file)
                let childDependencyContainer = dependencyGraph.dependencyContainer(type: injectableType.value.type,
                                                                                   accessLevel: injectableType.value.accessLevel,
                                                                                   doesSupportObjc: injectableType.value.doesSupportObjc,
                                                                                   fileLocation: fileLocation)
                try linkDependencyContainer(childDependencyContainer,
                                            with: children,
                                            embeddingTypes: embeddingTypes + [injectableType.value.type],
                                            file: file)
                
            case .registerAnnotation(let registerAnnotation):
                registerAnnotations.append(registerAnnotation)
                
            case .referenceAnnotation(let referenceAnnotation):
                referenceAnnotations.append(referenceAnnotation)
                
            case .configurationAnnotation(let configurationAnnotation):
                let target = configurationAnnotation.value.target
                configurationAnnotations[target] = (configurationAnnotations[target] ?? []) + [configurationAnnotation]
                
            case .parameterAnnotation(let parameterAnnotation):
                let parameter = Parameter(parameterName: parameterAnnotation.value.name,
                                          source: dependencyContainer,
                                          type: parameterAnnotation.value.type,
                                          fileLocation: FileLocation(line: parameterAnnotation.line, file: file))
                dependencyContainer.parameters.append(parameter)
                
            case .file:
                break
            }
        }
        
        dependencyContainer.configuration = DependencyContainerConfiguration(
            with: configurationAnnotations[.`self`]?.map { $0.value }
        )
        
        dependencyContainer.embeddingTypes = embeddingTypes
        
        for registerAnnotation in registerAnnotations {
            let name = registerAnnotation.value.name
            let registration = try dependencyGraph.registration(source: dependencyContainer,
                                                                registerAnnotation: registerAnnotation,
                                                                configuration: configurationAnnotations[.dependency(name: name)] ?? [],
                                                                file: file)
            let index = DependencyIndex(name: name, type: registration.target.type)
            dependencyContainer.registrations[index] = registration
            registration.target.sources.append(dependencyContainer)
        }
        
        for referenceAnnotation in referenceAnnotations {
            let name = referenceAnnotation.value.name
            let reference = try dependencyGraph.reference(source: dependencyContainer,
                                                          referenceAnnotation: referenceAnnotation,
                                                          configuration: configurationAnnotations[.dependency(name: name)] ?? [],
                                                          file: file)
            let index = DependencyIndex(name: name, type: reference.target.type)
            dependencyContainer.references[index] = reference
            reference.target.sources.append(dependencyContainer)
        }
    }
}
