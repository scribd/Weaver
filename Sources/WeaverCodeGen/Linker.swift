//
//  Linker.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 7/13/18.
//

import Foundation

// MARK: - DependencyContainer

/// Representation of a Dependency Container.
final class DependencyContainer: Encodable, CustomDebugStringConvertible {
    
    /// Associated type.
    let type: ConcreteType
    
    /// Access level of the associated type.
    let accessLevel: AccessLevel
    
    /// Configuration built based on the configuration annotations.
    fileprivate(set) var configuration = DependencyContainerConfiguration.empty
    
    /// Dependencies in order of appearance in the code.
    fileprivate(set) var dependencyNamesByConcreteType = OrderedDictionary<ConcreteType, Set<String>>()
    fileprivate(set) var dependencyNamesByAbstractType = OrderedDictionary<AbstractType, Set<String>>()
    fileprivate(set) var dependencies = OrderedDictionary<String, Dependency>()
    
    lazy var references = dependencies.orderedValues.filter { $0.kind == .reference }
    lazy var registrations = dependencies.orderedValues.filter { $0.kind == .registration }
    lazy var parameters = dependencies.orderedValues.filter { $0.kind == .parameter }
    
    /// Types from which this dependency container's associated type is being registered.
    fileprivate(set) var sources = Set<ConcreteType>()

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
    let embeddingTypes:  [ConcreteType]
    
    /// Location of the associated type declaration in the code.
    let fileLocation: FileLocation?

    enum DeclarationSource: String, Encodable {
        case type
        case registration
        case reference
    }
    
    /// Indicates where the declaration comes from. Used for debugging.
    let declarationSource: DeclarationSource
    
    init(type: ConcreteType,
         accessLevel: AccessLevel = .default,
         embeddingTypes: [ConcreteType] = [],
         fileLocation: FileLocation? = nil,
         declarationSource: DeclarationSource) {
        
        self.type = type
        self.accessLevel = accessLevel
        self.fileLocation = fileLocation
        self.embeddingTypes = embeddingTypes
        self.declarationSource = declarationSource
    }
    
    var debugDescription: String {
        return """
        DependencyContainer:
        - type: \(type)
        - accessLevel: \(accessLevel)
        - configuration: \(configuration)
        - dependencies: \(dependencies.orderedKeyValues.map { ($0.key, $0.value.type) })
        - sources: \(sources)
        - embeddingTypes: \(embeddingTypes)
        - declarationSource: \(declarationSource.rawValue)
        """
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
    - `scope` = .transient
    - `source` = `FooDependency`
 */
final class Dependency: Encodable, CustomDebugStringConvertible {
    
    enum Kind: String, Encodable, CaseIterable {
        case registration
        case reference
        case parameter
    }
    
    /// Kind of dependency
    let kind: Kind
    
    /// Name which was used to declare the dependency.
    let dependencyName: String

    enum `Type`: Hashable, CustomStringConvertible {
        case abstract(Set<AbstractType>) // Reference only
        case concrete(ConcreteType) // Reference, registration or parameter
        case full(ConcreteType, Set<AbstractType>) // Registration only
    }
    
    /// Type which was used to declare the dependency.
    let type: `Type`
    
    /// Configuration built based on the configuration annotations
    /// associated to the same dependency name.
    fileprivate(set) var configuration: DependencyConfiguration = .empty

    /// Dependency container which contains the dependency.
    let source: ConcreteType
    
    /// Style of annotation used to declare the dependency.
    let annotationStyle: AnnotationStyle
    
    /// Location of the declarative annotation in the source code.
    let fileLocation: FileLocation?
    
    init(kind: Kind,
         dependencyName: String,
         type: `Type`,
         source: ConcreteType,
         annotationStyle: AnnotationStyle,
         fileLocation: FileLocation) {
        
        self.kind = kind
        self.dependencyName = dependencyName
        self.type = type
        self.annotationStyle = annotationStyle
        self.source = source
        self.fileLocation = fileLocation
    }
    
    var debugDescription: String {
        return """
        \(kind.rawValue.capitalized):
        - name: \(dependencyName)
        - type: \(type)
        - configuration: \(configuration)
        - source: \(source)
        - fileLocation: \(fileLocation ?? FileLocation(line: nil, file: nil))
        """
    }
}

// MARK: - Graph

/// Representation of the dependency graph.
///
/// - Note: Indexes the dependency containers and dependencies.
public final class DependencyGraph {
    
    /// Imported module names.
    fileprivate(set) var imports = Set<String>()
    
    /// Abstract types by concrete type.
    fileprivate(set) var abstractTypes = [ConcreteType: Set<AbstractType>]()
    
    /// Concrete types by abtract type.
    fileprivate(set) var concreteTypes = [AbstractType: [String: ConcreteType]]()

    /// Concrete types with no abstract types.
    fileprivate(set) var orphinConcreteTypes = [String: Set<ConcreteType>]()
    
    /// `DependencyContainer`s by concrete type and iterable in order of appearance in the source code.
    fileprivate(set) var dependencyContainers = OrderedDictionary<ConcreteType, DependencyContainer>()

    /// All dependencies in order of appearance in the code.
    lazy var dependencies = dependencyContainers.orderedValues.flatMap { $0.dependencies.orderedValues }

    /// Count of types with annotations.
    public lazy var injectableTypesCount = dependencyContainers.orderedValues.filter { $0.dependencies.isEmpty == false }.count

    /// Contains at least one annotation using a property wrapper.
    lazy var hasPropertyWrapperAnnotations = dependencies.contains { $0.annotationStyle == .propertyWrapper }

    // MARK: - Cached data
    
    private var hasSelfReferenceCache = [ObjectIdentifier: Bool]()
    private var concreteTypeCache = [ObjectIdentifier: ConcreteType]()
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

// MARK: - Build

private extension Linker {
    
    /// Fills the dependency graph by visiting one or plural ASTs.
    ///
    /// 1. Link types (Abstract <-> Concrete)
    /// 2. Collect dependency containers
    /// 3. Link dependency containers (DC <- dependency -> DC)
    ///
    /// - Parameter syntaxTrees: ASTs to visit.
    /// - Throws: `LinkerError` or `DependencyGraphError`.
    func buildDependencyGraph(from syntaxTrees: [Expr]) throws {
        linkAbstractTypesToConcreteTypes(from: syntaxTrees)
        try collectDependencyContainers(from: syntaxTrees)
        try linkDependencyContainers(from: syntaxTrees)
    }
}

// MARK: - Collect

private extension Linker {
    
    func collectDependencyContainers(from syntaxTrees: [Expr]) throws {

        // Collect dependency containers
        
        let typeDeclarations = OrderedDictionary<ConcreteType, DependencyContainer>()
        let registerAnnotations = OrderedDictionary<ConcreteType, DependencyContainer>()
        let referenceAnnotations = OrderedDictionary<ConcreteType, DependencyContainer>()
        
        var configurationAnnotations = [ConcreteType: [ConfigurationAttributeName: ConfigurationAttribute]]()
        
        for (expr, embeddingTypes, file) in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .file(_, _, let imports):
                imports.forEach { dependencyGraph.imports.insert($0) }

            case .typeDeclaration(let token, _):
                let location = FileLocation(line: token.line, file: file)
                
                let dependencyContainer = DependencyContainer(type: token.value.type,
                                                              accessLevel: token.value.accessLevel,
                                                              embeddingTypes: embeddingTypes,
                                                              fileLocation: location,
                                                              declarationSource: .type)
                typeDeclarations[dependencyContainer.type] = dependencyContainer

            case .registerAnnotation(let token):
                let dependencyContainer = DependencyContainer(type: token.value.type,
                                                              declarationSource: .registration)
                registerAnnotations[dependencyContainer.type] = dependencyContainer
                
            case .referenceAnnotation(let token):
                let location = FileLocation(line: token.line, file: file)
                let dependencyType = dependencyGraph.dependencyType(for: token.value.types,
                                                                    dependencyName: token.value.name)
                
                let concreteType = try dependencyGraph.concreteType(for: dependencyType,
                                                                    dependencyName: token.value.name,
                                                                    at: location)

                let dependencyContainer = DependencyContainer(type: concreteType,
                                                              declarationSource: .reference)

                referenceAnnotations[dependencyContainer.type] = dependencyContainer

            case .configurationAnnotation(let token):
                if token.value.target == .`self` {
                    guard let concreteType = embeddingTypes.last else {
                        let location = FileLocation(line: token.line, file: file)
                        throw LinkerError.foundAnnotationOutsideOfType(location)
                    }

                    var attributes = configurationAnnotations[concreteType] ?? [:]
                    attributes[token.value.attribute.name] = token.value.attribute
                    configurationAnnotations[concreteType] = attributes
                }
                
            case .parameterAnnotation:
                break
            }
        }

        // Fill the graph
        
        for dependencyContainer in typeDeclarations.orderedValues {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        for dependencyContainer in registerAnnotations.orderedValues where dependencyGraph.dependencyContainers[dependencyContainer.type] == nil {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        for dependencyContainer in referenceAnnotations.orderedValues where dependencyGraph.dependencyContainers[dependencyContainer.type] == nil {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        
        // Fill dependency containers' configurations

        for (type, attributes) in configurationAnnotations {
            dependencyGraph.dependencyContainers[type]?.configuration = DependencyContainerConfiguration(with: attributes)
        }
    }
}

// MARK: - Link

private extension Linker {
    
    func linkAbstractTypesToConcreteTypes(from syntaxTrees: [Expr]) {
        
        for (expr, _, _) in ExprSequence(exprs: syntaxTrees) {
            if let token = expr.toRegisterAnnotation() {
                if token.value.protocolTypes.isEmpty == false {
                    for abstractType in token.value.protocolTypes {
                        var concreteTypes = dependencyGraph.concreteTypes[abstractType] ?? [:]
                        concreteTypes[token.value.name] = token.value.type
                        dependencyGraph.concreteTypes[abstractType] = concreteTypes
                        
                        var abstractTypes = dependencyGraph.abstractTypes[token.value.type] ?? Set()
                        abstractTypes.insert(abstractType)
                        dependencyGraph.abstractTypes[token.value.type] = abstractTypes
                    }
                } else {
                    var concreteTypes = dependencyGraph.orphinConcreteTypes[token.value.name] ?? Set()
                    concreteTypes.insert(token.value.type)
                    dependencyGraph.orphinConcreteTypes[token.value.name] = concreteTypes
                }
            }
        }
    }
    
    func linkDependencyContainers(from syntaxTrees: [Expr]) throws {
        
        var configurationAnnotations = [ConcreteType: [String: [ConfigurationAttribute]]]()

        for (expr, embeddingTypes, file) in ExprSequence(exprs: syntaxTrees) {
            switch expr {
            case .registerAnnotation(let token):
                let location = FileLocation(line: token.line, file: file)

                guard let source = embeddingTypes.last else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }
                
                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source)
                }

                let dependency = Dependency(kind: .registration,
                                            dependencyName: token.value.name,
                                            type: .init(token.value.type, token.value.protocolTypes),
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)
                
                sourceDependencyContainer.insertDependency(dependency)
                
                let associatedDependencyContainer = try dependencyGraph.dependencyContainer(for: dependency)
                associatedDependencyContainer.sources.insert(dependency.source)
                
            case .referenceAnnotation(let token):
                let location = FileLocation(line: token.line, file: file)

                guard let source = embeddingTypes.last else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }
                
                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source)
                }

                let dependencyType = dependencyGraph.dependencyType(for: token.value.types,
                                                                    dependencyName: token.value.name)
                let dependency = Dependency(kind: .reference,
                                            dependencyName: token.value.name,
                                            type: dependencyType,
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)

                sourceDependencyContainer.insertDependency(dependency)

            case .parameterAnnotation(let token):
                let location = FileLocation(line: token.line, file: file)
                
                guard let source = embeddingTypes.last else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }

                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source)
                }

                let dependency = Dependency(kind: .parameter,
                                            dependencyName: token.value.name,
                                            type: .concrete(token.value.type),
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)
                
                sourceDependencyContainer.insertDependency(dependency)

            case .configurationAnnotation(let token):
                if case .dependency(let name) = token.value.target {

                    guard let concreteType = embeddingTypes.last else {
                        let location = FileLocation(line: token.line, file: file)
                        throw LinkerError.foundAnnotationOutsideOfType(location)
                    }
                    
                    var attributesByDependencyName = configurationAnnotations[concreteType] ?? [:]
                    var attributes = attributesByDependencyName[name] ?? []
                    attributes.append(token.value.attribute)
                    attributesByDependencyName[name] = attributes
                    configurationAnnotations[concreteType] = attributesByDependencyName
                }
                
            case .file,
                 .typeDeclaration:
                break
            }
        }
        
        for (type, attributes) in configurationAnnotations {
            
            guard let dependencyContainer = dependencyGraph.dependencyContainers[type] else {
                throw LinkerError.unknownType(nil, type: type)
            }
            
            for (dependencyName, attributes) in attributes {
                guard let dependency = dependencyContainer.dependencies[dependencyName] else {
                    throw LinkerError.dependencyNotFound(nil, dependencyName: dependencyName)
                }
                dependency.configuration = DependencyConfiguration(with: attributes)
            }
        }
    }
}

private extension DependencyContainer {
    
    func insertDependency(_ dependency: Dependency) {
        
        if let concreteType = dependency.type.concreteType {
            var dependencyNames = dependencyNamesByConcreteType[concreteType] ?? Set()
            dependencyNames.insert(dependency.dependencyName)
            dependencyNamesByConcreteType[concreteType] = dependencyNames
        }
        
        for abstractType in dependency.type.abstractTypes {
            var dependencyNames = dependencyNamesByAbstractType[abstractType] ?? Set()
            dependencyNames.insert(dependency.dependencyName)
            dependencyNamesByAbstractType[abstractType] = dependencyNames
        }
        
        dependencies[dependency.dependencyName] = dependency
    }
}

// MARK: - CustomStringConvertible

extension Dependency.`Type` {

    var description: String {
        switch self {
        case .abstract(let types):
            return types.map { $0.description }.joined(separator: " & ")
        case .concrete(let type):
            return type.description
        case .full(let concreteType, let abstractTypes):
            return "\(concreteType) <- \(abstractTypes.map { $0.description }.joined(separator: " & "))"
        }
    }
}

// MARK: - Utils

extension DependencyGraph {
    
    func dependencyContainer(for concreteType: ConcreteType, at location: FileLocation? = nil) throws -> DependencyContainer {
        guard let value = dependencyContainers[concreteType] else {
            throw DependencyGraphError.dependencyContainerNotFound(location, type: concreteType)
        }
        return value
    }
    
    func dependencyContainer(for dependency: Dependency) throws -> DependencyContainer {
        let concreteType = try self.concreteType(for: dependency)
        
        guard let dependencyContainer = dependencyContainers[concreteType] else {
            throw DependencyGraphError.dependencyContainerNotFound(dependency.fileLocation, type: concreteType)
        }
        
        return dependencyContainer
    }
    
    func concreteType(for dependency: Dependency) throws -> ConcreteType {
        if let value = concreteTypeCache[ObjectIdentifier(dependency)] {
            return value
        }
        let value = try concreteType(for: dependency.type,
                                     dependencyName: dependency.dependencyName,
                                     at: dependency.fileLocation)
        concreteTypeCache[ObjectIdentifier(dependency)] = value
        return value
    }
    
    func concreteType(for dependencyType: Dependency.`Type`,
                      dependencyName: String,
                      at location: FileLocation? = nil) throws -> ConcreteType {
        
        switch dependencyType {
        case .abstract(let abstractTypes):
            var candidates = [String: ConcreteType]()
            let concreteTypes = Set(abstractTypes.lazy.map { abstractType -> ConcreteType in
                guard let concreteTypes = self.concreteTypes[abstractType] else {
                    return abstractType.concreteType
                }
                if let concreteType = concreteTypes[dependencyName] {
                    candidates[dependencyName] = concreteType
                    return concreteType
                } else if concreteTypes.count == 1 {
                    for (name, type) in concreteTypes {
                        candidates[name] = type
                    }
                    return concreteTypes.values.first!
                } else {
                    return abstractType.concreteType
                }
            })
            guard concreteTypes.count == 1 else {
                let candidates = candidates.lazy.map { ($0, $1) }.sorted { $0.0 < $1.0 }
                throw DependencyGraphError.invalidAbstractTypeComposition(location, types: abstractTypes, candidates: candidates)
            }
            return concreteTypes.first!
            
        case .concrete(let concreteType),
             .full(let concreteType, _):
            return concreteType
        }
    }
    
    func dependencyType(for types: Set<AbstractType>,
                        dependencyName: String) -> Dependency.`Type` {
        
        guard types.count == 1 else { return .abstract(types) }
        
        let type = types.first!
        if self.abstractTypes[type.concreteType] != nil {
            return .concrete(type.concreteType)
        } else if let concreteTypes = orphinConcreteTypes[dependencyName], concreteTypes.contains(type.concreteType) {
            return .concrete(type.concreteType)
        } else if concreteTypes[type] != nil {
            return .abstract(Set([type]))
        } else {
            return .concrete(type.concreteType)
        }
    }
    
    func isSelfReference(_ dependency: Dependency) throws -> Bool {
        guard dependency.kind == .reference else { return false }
        let concreteType = try self.concreteType(for: dependency)
        return concreteType == dependency.source
    }
    
    func hasSelfReference(_ dependencyContainer: DependencyContainer) throws -> Bool {
        if let value = hasSelfReferenceCache[ObjectIdentifier(dependencyContainer)] {
            return value
        }
        let value = try _hasSelfReference(dependencyContainer)
        hasSelfReferenceCache[ObjectIdentifier(dependencyContainer)] = value
        return value
    }
    
    private func _hasSelfReference(_ dependencyContainer: DependencyContainer) throws -> Bool {
        return try dependencyContainer.dependencies.orderedValues.contains { dependency in
            try isSelfReference(dependency)
        }
    }
}

extension Dependency.Kind {
    
    var isResolvable: Bool {
        switch self {
        case .reference,
             .registration:
            return true
        case .parameter:
            return false
        }
    }
}

extension Dependency.`Type` {
    
    var abstractTypes: Set<AbstractType> {
        switch self {
        case .full(_, let types):
            return types
        case .abstract(let types):
            return types
        case .concrete:
            return Set()
        }
    }
    
    var concreteType: ConcreteType? {
        switch self {
        case .concrete(let type),
             .full(let type, _):
            return type
        case .abstract:
            return nil
        }
    }
    
    var types: Set<AnyType> {
        switch self {
        case .full(let concreteType, let abstractTypes):
            return abstractTypes.isEmpty ? Set([concreteType]) : abstractTypes
        case .abstract(let types):
            return types
        case .concrete(let type):
            return Set([type])
        }
    }
    
    init(_ concreteType: ConcreteType, _ abstractTypes: Set<AbstractType>) {
        if abstractTypes.isEmpty == false {
            self = .full(concreteType, abstractTypes)
        } else {
            self = .concrete(concreteType)
        }
    }
    
    static func ~= (_ lhs: Dependency.`Type`, _ rhs: Dependency.`Type`) -> Bool {
        switch (lhs, rhs) {
        case (.abstract(let lhs), .abstract(let rhs)):
            return lhs == rhs
        case (.full(_, let lhs), .abstract(let rhs)):
            return rhs.isSubset(of: lhs)
        case (.abstract(let lhs), .full(_, let rhs)):
            return lhs.isSubset(of: rhs)
        case (.concrete(let lhs), .concrete(let rhs)):
            return lhs == rhs
        case (.full(let lConcreteType, let lAbstractType), .full(let rConcreteType, let rAbstractType)):
            guard lConcreteType == rConcreteType else { return false }
            guard lAbstractType == rAbstractType else { return false }
            return true
        case (.abstract, _),
             (.concrete, _),
             (.full, _):
            return false
        }
    }
}

extension Set where Element == AbstractType {
    
    func contains(_ member: ConcreteType?) -> Bool {
        guard let member = member else {
            return false
        }
        return contains(member.abstractType)
    }
}

extension Sequence where Element: AnyType {
    
    var sorted: [Element] {
        return sorted { $0.description < $1.description }
    }
}
