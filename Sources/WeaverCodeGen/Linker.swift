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
    
    fileprivate(set) lazy var references = dependencies.orderedValues.filter { $0.kind == .reference }
    fileprivate(set) lazy var registrations = dependencies.orderedValues.filter { $0.kind == .registration }
    fileprivate(set) lazy var parameters = dependencies.orderedValues.filter { $0.kind == .parameter }
    
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
    let embeddingTypes: [ConcreteType]
    
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
        case abstract(AbstractType) // Reference only
        case concrete(ConcreteType) // Reference, registration or parameter
        case full(ConcreteType, AbstractType) // Registration only
    }
    
    /// Type which was used to declare the dependency.
    let type: `Type`
    
    /// Contains parameters used when declared. For property wrappers only.
    let closureParameters: [TupleComponent]
    
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
         closureParameters: [TupleComponent],
         source: ConcreteType,
         annotationStyle: AnnotationStyle,
         fileLocation: FileLocation) {
        
        self.kind = kind
        self.dependencyName = dependencyName
        self.type = type
        self.closureParameters = closureParameters
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
    
    /// Platforms.
    fileprivate(set) var platforms = Set<String>()
    
    /// Abstract types by concrete type.
    fileprivate(set) var abstractTypes = [ConcreteType: AbstractType]()
    
    /// Concrete types by abtract type.
    fileprivate(set) var concreteTypes = [AbstractType: [String: ConcreteType]]()

    /// Concrete types with no abstract types.
    fileprivate(set) var orphinConcreteTypes = [String: Set<ConcreteType>]()
    
    /// `DependencyContainer`s by concrete type and iterable in order of appearance in the source code.
    fileprivate(set) var dependencyContainers = OrderedDictionary<ConcreteType, DependencyContainer>()

    /// All dependencies in order of appearance in the code.
    fileprivate(set) lazy var dependencies = dependencyContainers.orderedValues.flatMap { $0.dependencies.orderedValues }

    /// Count of types with annotations.
    public fileprivate(set) lazy var injectableTypesCount = dependencyContainers.orderedValues.filter { $0.dependencies.isEmpty == false }.count

    /// Contains at least one annotation using a property wrapper.
    fileprivate(set) lazy var hasPropertyWrapperAnnotations = dependencies.contains { $0.annotationStyle == .propertyWrapper }

    /// The root node of the graph, that which is not referenced by any other container
    fileprivate(set) lazy var rootContainers: [DependencyContainer] = dependencyContainers.orderedValues.filter { $0.sources.isEmpty }

    /// The concrete types that are explicitly excluded per platform or project
    fileprivate(set) lazy var excludedConcreteTypes = Set<ConcreteType>()

    /// The abstract reference names that are explicitly excluded per platform or project per class
    fileprivate(set) lazy var excludedAbstractReferencesPerClass = [ConcreteType: Set<String>]()

    /// The concrete types that are explicitly included per platform or project
    fileprivate(set) lazy var includedConcreteTypes = Set<ConcreteType>()

    /// The abstract reference names that are explicitly included per platform or project per class
    fileprivate(set) lazy var includedAbstractReferencesPerClass = [ConcreteType: Set<String>]()

    /// The abstract reference names that are explicitly included per platform or project per class
    public fileprivate(set) lazy var uniqueProjects = Set<String>()

    // MARK: - Cached data
    
    private var hasSelfReferenceCache = [ObjectIdentifier: Bool]()
    private var concreteTypeCache = [ObjectIdentifier: ConcreteType]()
}

/// Object in charge of going through the AST for each file, and link dependency containers
/// together to produce the dependency graph.
public final class Linker {

    /// Produced dependency graph
    public let dependencyGraph = DependencyGraph()
    
    private let platform: Platform?

    private let projectName: String?

    /// - Parameters
    ///     - syntaxTrees: list of syntax trees (AST) for each source file.
    ///     - platform: target platform for which the code is generated.
    ///
    /// - Throws:
    ///     - `InspectorError.invalidDependencyGraph` // TODO: Create a specific error type for the linker.
    public init(syntaxTrees: [Expr],
                platform: Platform? = nil,
                projectName: String? = nil) throws {
        self.platform = platform
        self.projectName = projectName
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

        var currentTypeLookup: [String: ConcreteType] = [:]
        var currentReferences: Set<String> = []
        var currentExcludedReferences: Set<String> = []

        var currentClass: ConcreteType?

        let addToIncludedList: (ConcreteType?, String, ConcreteType) -> Void = { concreteType, reference, classType in
            if let concreteType = concreteType {
                self.dependencyGraph.includedConcreteTypes.insert(concreteType)
            }

            var includedRefsPerClass = self.dependencyGraph.includedAbstractReferencesPerClass[classType] ?? []
            includedRefsPerClass.insert(reference)
            self.dependencyGraph.includedAbstractReferencesPerClass[classType] = includedRefsPerClass
        }

        let addToExcludeList: (ConcreteType?, String, ConcreteType) -> Void = { concreteType, reference, classType in
            if let concreteType = concreteType {
                self.dependencyGraph.excludedConcreteTypes.insert(concreteType)
            }

            var excludedRefsPerClass = self.dependencyGraph.excludedAbstractReferencesPerClass[classType] ?? []
            excludedRefsPerClass.insert(reference)
            self.dependencyGraph.excludedAbstractReferencesPerClass[classType] = excludedRefsPerClass
        }

        let updateLists: (ConcreteType?) -> Void = { classType in
            guard let classType = classType else { return }
            for reference in currentReferences {
                if currentExcludedReferences.contains(reference) {
                    addToExcludeList(currentTypeLookup[reference], reference, classType)
                } else {
                    addToIncludedList(currentTypeLookup[reference], reference, classType)
                }
            }
        }

        for (expr, embeddingTypes, file) in ExprSequence(exprs: syntaxTrees) {

            switch expr {
            case .typeDeclaration(let token, _):
                updateLists(currentClass)
                currentTypeLookup = [:]
                currentExcludedReferences = []
                currentClass = token.value.type
            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .configurationAnnotation,
                 .parameterAnnotation:
                break
            }

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

                currentTypeLookup[token.value.name] = token.value.type
                currentReferences.insert(token.value.name)

            case .referenceAnnotation(let token):
                let location = FileLocation(line: token.line, file: file)
                let dependencyType = dependencyGraph.dependencyType(for: token.value.type,
                                                                    dependencyName: token.value.name)
                
                let concreteType = try dependencyGraph.concreteType(for: dependencyType,
                                                                    dependencyName: token.value.name,
                                                                    at: location)

                let dependencyContainer = DependencyContainer(type: concreteType,
                                                              declarationSource: .reference)

                referenceAnnotations[dependencyContainer.type] = dependencyContainer
                currentReferences.insert(token.value.name)

            case .configurationAnnotation(let token):

                let excludeTarget: (ConfigurationAttributeTarget) -> Bool = { target in
                    switch target {
                    case .`self`:
                        return false
                    case .dependency(name: let dependencyName):
                        currentReferences.insert(dependencyName)
                        currentExcludedReferences.insert(dependencyName)
                        return true
                    }
                }

                switch token.value.attribute {
                case .isIsolated,
                        .customBuilder,
                        .scope,
                        .doesSupportObjc,
                        .setter,
                        .escaping:
                    break
                case .platforms(let platforms):
                    if let platform = platform,
                        platforms.isEmpty == false,
                        platforms.contains(platform) == false,
                        excludeTarget(token.value.target) {
                       continue
                    }
                case .projects(let projects):
                    projects.forEach { dependencyGraph.uniqueProjects.insert($0) }
                    if let projectName = projectName,
                        projects.isEmpty == false,
                        projects.contains(projectName) == false,
                        excludeTarget(token.value.target) {
                        continue
                    }
                }

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

        if currentReferences.isEmpty == false {
            updateLists(currentClass)
        }

        // Fill the graph

        let excludedTypes = dependencyGraph.excludedConcreteTypes
        let includedTypes = dependencyGraph.includedConcreteTypes

        let isAvailable: (ConcreteType) -> Bool = { concreteType in
            return includedTypes.contains(concreteType)
                || excludedTypes.contains(concreteType) == false
        }

        for dependencyContainer in typeDeclarations.orderedValues where isAvailable(dependencyContainer.type) {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        for dependencyContainer in registerAnnotations.orderedValues where dependencyGraph.dependencyContainers[dependencyContainer.type] == nil && isAvailable(dependencyContainer.type) {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        for dependencyContainer in referenceAnnotations.orderedValues where dependencyGraph.dependencyContainers[dependencyContainer.type] == nil && isAvailable(dependencyContainer.type) {
            dependencyGraph.dependencyContainers[dependencyContainer.type] = dependencyContainer
        }
        
        // Fill dependency containers' configurations

        for (type, attributes) in configurationAnnotations where isAvailable(type) {
            dependencyGraph.dependencyContainers[type]?.configuration = DependencyContainerConfiguration(with: attributes)
        }
    }
}

// MARK: - Link

private extension Linker {
    
    func linkAbstractTypesToConcreteTypes(from syntaxTrees: [Expr]) {
        
        for (expr, _, _) in ExprSequence(exprs: syntaxTrees) {
            if let token = expr.toRegisterAnnotation() {
                if token.value.abstractType.isEmpty == false {
                    for abstractType in token.value.abstractType {
                        var concreteTypes = dependencyGraph.concreteTypes[abstractType] ?? [:]
                        concreteTypes[token.value.name] = token.value.type
                        dependencyGraph.concreteTypes[abstractType] = concreteTypes
                        
                        var abstractType = dependencyGraph.abstractTypes[token.value.type] ?? AbstractType(value: .components(Set()))
                        abstractType.formUnion(with: abstractType)
                        dependencyGraph.abstractTypes[token.value.type] = abstractType
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
        var registrationConcreteTypes = [String: [ConcreteType]]()

        let excludedConcreteTypes = dependencyGraph.excludedConcreteTypes
        let excludedAbstractRefsPerClass = dependencyGraph.excludedAbstractReferencesPerClass

        let includedConcreteTypes = dependencyGraph.includedConcreteTypes
        let includedAbstractRefsPerClass = dependencyGraph.includedAbstractReferencesPerClass

        var currentClass: ConcreteType?

        // Step 1: Build all configurations
        for (expr, embeddingTypes, file) in ExprSequence(exprs: syntaxTrees) {

            switch expr {
            case .typeDeclaration(let token, _):
                currentClass = token.value.type
            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .configurationAnnotation,
                 .parameterAnnotation:
                break
            }

            let excludedAbstractRefs = currentClass.flatMap { excludedAbstractRefsPerClass[$0] } ?? []
            let includedAbstractRefs = currentClass.flatMap { includedAbstractRefsPerClass[$0] } ?? []

            switch expr {
            case .referenceAnnotation,
                 .parameterAnnotation,
                 .file,
                 .typeDeclaration:
                break

            case .registerAnnotation(let token):
                let existingTypes: [ConcreteType] = registrationConcreteTypes[token.value.name] ?? []
                registrationConcreteTypes[token.value.name] = existingTypes + token.value.type

            case .configurationAnnotation(let token):
                if case .dependency(let dependencyName) = token.value.target {

                    if excludedAbstractRefs.contains(dependencyName) && includedAbstractRefs.contains(dependencyName) == false {
                        continue
                    }

                    guard let concreteType = embeddingTypes.last else {
                        let location = FileLocation(line: token.line, file: file)
                        throw LinkerError.foundAnnotationOutsideOfType(location)
                    }

                    if excludedConcreteTypes.contains(concreteType) && includedConcreteTypes.contains(concreteType) == false {
                        continue
                    }

                    if let associatedConcreteType = registrationConcreteTypes[dependencyName]?.last,
                       excludedConcreteTypes.contains(associatedConcreteType),
                       includedConcreteTypes.contains(associatedConcreteType) == false {
                        continue
                    }

                    var attributesByDependencyName = configurationAnnotations[concreteType] ?? [:]
                    var attributes = attributesByDependencyName[dependencyName] ?? []
                    attributes.append(token.value.attribute)
                    attributesByDependencyName[dependencyName] = attributes
                    configurationAnnotations[concreteType] = attributesByDependencyName
                }
            }
        }

        currentClass = nil

        // Step 2: Parse the dependencies
        for (expr, embeddingTypes, file) in ExprSequence(exprs: syntaxTrees) {

            switch expr {
            case .typeDeclaration(let token, _):
                currentClass = token.value.type
            case .file,
                 .registerAnnotation,
                 .referenceAnnotation,
                 .configurationAnnotation,
                 .parameterAnnotation:
                break
            }

            let excludedAbstractRefs = currentClass.flatMap { excludedAbstractRefsPerClass[$0] } ?? []
            let includedAbstractRefs = currentClass.flatMap { includedAbstractRefsPerClass[$0] } ?? []

            switch expr {
            case .registerAnnotation(let token):

                if excludedAbstractRefs.contains(token.value.name) && includedAbstractRefs.contains(token.value.name) == false {
                    continue
                }

                if excludedConcreteTypes.contains(token.value.type) && includedConcreteTypes.contains(token.value.type) == false {
                    continue
                }

                if embeddingTypes.allAreExcluded(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) {
                    continue
                }

                let location = FileLocation(line: token.line, file: file)

                guard let source = embeddingTypes.first(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }

                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source.value)
                }

                let dependency = Dependency(kind: .registration,
                                            dependencyName: token.value.name,
                                            type: .init(token.value.type, token.value.abstractType),
                                            closureParameters: token.value.closureParameters,
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)
                
                sourceDependencyContainer.insertDependency(dependency)
                
                let associatedDependencyContainer = try dependencyGraph.dependencyContainer(for: dependency)
                associatedDependencyContainer.sources.insert(dependency.source)
                
            case .referenceAnnotation(let token):

                if excludedAbstractRefs.contains(token.value.name) && includedAbstractRefs.contains(token.value.name) == false {
                    continue
                }

                if embeddingTypes.allAreExcluded(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) {
                    continue
                }

                let location = FileLocation(line: token.line, file: file)

                guard let source = embeddingTypes.first(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }
                
                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source.value)
                }

                let dependencyType = dependencyGraph.dependencyType(for: token.value.type,
                                                                    dependencyName: token.value.name)
                let dependency = Dependency(kind: .reference,
                                            dependencyName: token.value.name,
                                            type: dependencyType,
                                            closureParameters: token.value.closureParameters,
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)

                sourceDependencyContainer.insertDependency(dependency)

            case .parameterAnnotation(let token):

                if excludedAbstractRefs.contains(token.value.name) && includedAbstractRefs.contains(token.value.name) == false {
                    continue
                }

                if excludedConcreteTypes.contains(token.value.type) && includedConcreteTypes.contains(token.value.type) == false {
                    continue
                }

                if embeddingTypes.allAreExcluded(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) {
                    continue
                }

                let location = FileLocation(line: token.line, file: file)

                guard let source = embeddingTypes.first(excludedTypes: excludedConcreteTypes, includedTypes: includedConcreteTypes) else {
                    throw LinkerError.foundAnnotationOutsideOfType(location)
                }

                guard let sourceDependencyContainer = dependencyGraph.dependencyContainers[source] else {
                    throw LinkerError.unknownType(location, type: source.value)
                }

                let dependency = Dependency(kind: .parameter,
                                            dependencyName: token.value.name,
                                            type: .concrete(token.value.type),
                                            closureParameters: [],
                                            source: source,
                                            annotationStyle: token.value.style,
                                            fileLocation: location)
                
                sourceDependencyContainer.insertDependency(dependency)

            case .configurationAnnotation,
                 .file,
                 .typeDeclaration:
                break
            }
        }
        
        for (concreteType, attributeDictionary) in configurationAnnotations {

            guard let dependencyContainer = dependencyGraph.dependencyContainers[concreteType] else {
                throw LinkerError.unknownType(nil, type: concreteType.value)
            }
            
            for (dependencyName, attributes) in attributeDictionary {
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
        
        for abstractType in dependency.type.abstractType {
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
            return "\(concreteType.description) <- \(abstractTypes.map { $0.description }.joined(separator: " & "))"
        }
    }
}

// MARK: - Utils

extension DependencyGraph {
    
    func dependencyContainer(for concreteType: ConcreteType, at location: FileLocation? = nil) throws -> DependencyContainer {
        guard let value = dependencyContainers[concreteType] else {
            throw DependencyGraphError.dependencyContainerNotFound(location, type: concreteType.value)
        }
        return value
    }
    
    func dependencyContainer(for dependency: Dependency) throws -> DependencyContainer {
        let concreteType = try self.concreteType(for: dependency)
        
        guard let dependencyContainer = dependencyContainers[concreteType] else {
            throw DependencyGraphError.dependencyContainerNotFound(dependency.fileLocation, type: concreteType.value)
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
        case .abstract(let abstractType):
            var candidates = [String: ConcreteType]()
            let concreteTypes = Set(abstractType.lazy.map { abstractType -> ConcreteType in
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
                throw DependencyGraphError.invalidAbstractTypeComposition(location, type: abstractType, candidates: candidates)
            }
            return concreteTypes.first!
            
        case .concrete(let concreteType),
             .full(let concreteType, _):
            return concreteType
        }
    }
    
    func dependencyType(for type: AbstractType,
                        dependencyName: String) -> Dependency.`Type` {
        
        guard type.value.count == 1 else { return .abstract(type) }
        
        let type = type.first!
        if self.abstractTypes[type.concreteType] != nil {
            return .concrete(type.concreteType)
        } else if let concreteTypes = orphinConcreteTypes[dependencyName], concreteTypes.contains(type.concreteType) {
            return .concrete(type.concreteType)
        } else if concreteTypes[type] != nil {
            return .abstract(AbstractType().union(type))
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

    var isRegistration: Bool {
        switch self {
        case .registration:
            return true
        case .parameter,
             .reference:
            return false
        }
    }
}

extension Dependency.`Type` {
    
    var abstractType: AbstractType {
        switch self {
        case .full(_, let type),
             .abstract(let type):
            return type
        case .concrete:
            return AbstractType(value: .components(Set()))
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
    
    var anyType: CompositeType {
        switch self {
        case .full(let concreteType, let abstractType):
            return abstractType.isEmpty ? concreteType.value : abstractType.value
        case .abstract(let type):
            return type.value
        case .concrete(let type):
            return type.value
        }
    }
    
    init(_ concreteType: ConcreteType, _ abstractType: AbstractType) {
        if abstractType.isEmpty == false {
            self = .full(concreteType, abstractType)
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

extension Sequence where Element: CustomStringConvertible {
    
    var sorted: [Element] {
        return sorted { $0.description < $1.description }
    }
}

private extension DependencyConfiguration {
    
    func contains(platform: Platform?) throws -> Bool {
        guard platforms.isEmpty == false else { return true }
        guard let platform = platform else {
            throw LinkerError.missingTargetedPlatform
        }
        return platforms.contains(platform)
    }
}

private extension Array where Element == ConcreteType {

    func allAreExcluded(excludedTypes: Set<ConcreteType>, includedTypes: Set<ConcreteType>) -> Bool {
        return allSatisfy { excludedTypes.contains($0) && includedTypes.contains($0) == false }
    }

    func first(excludedTypes: Set<ConcreteType>, includedTypes: Set<ConcreteType>) -> ConcreteType? {
        return first { excludedTypes.contains($0) == false || includedTypes.contains($0) }
    }
}

// MARK: - Defaults

extension Linker {

    enum Defaults {
        static let unnamedFile = "UnnamedFile"
    }
}
