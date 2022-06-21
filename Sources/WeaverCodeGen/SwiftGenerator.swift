//
//  SwiftGenerator.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation
import PathKit
import Meta
import CommonCrypto

public final class SwiftGenerator {
    
    private let dependencyGraph: DependencyGraph
    
    private let inspector: Inspector
    
    private let testableImports: [String]?

    private let version: String

    private let swiftlintDisableAll: Bool
    
    public typealias ImportFilter = (String) -> Bool
    private let importFilter: ImportFilter
    
    public init(dependencyGraph: DependencyGraph,
                inspector: Inspector,
                version: String,
                testableImports: [String]?,
                swiftlintDisableAll: Bool,
                importFilter: @escaping ImportFilter) throws {

        self.dependencyGraph = dependencyGraph
        self.inspector = inspector
        self.version = version
        self.testableImports = testableImports?.filter(importFilter)
        self.swiftlintDisableAll = swiftlintDisableAll
        self.importFilter = importFilter
    }
    
    private var _file: MetaWeaverFile?
    private func file() throws -> MetaWeaverFile {
        if let file = _file {
            return file
        }
        let file = try MetaWeaverFile(
            dependencyGraph,
            inspector,
            version,
            testableImports,
            swiftlintDisableAll,
            importFilter
        )
        _file = file
        return file
    }
    
    public func generate() throws -> String {
        try file().meta().swiftString
    }
    
    public func generateTests() throws -> String {
        try file().metaTests().swiftString
    }
}

// MARK: - Dependency Declaration

private final class MetaDependencyDeclaration: Hashable {
    
    struct Parameter {
        let name: String
        let type: ConcreteType
    }
    
    let name: String
    
    let type: Dependency.`Type`
    
    let scope: Scope

    let parameters: [Dependency]

    private let includeTypeInName: Bool
    
    private let includeParametersInName: Bool
    
    init(for dependency: Dependency,
         in dependencyGraph: DependencyGraph,
         includeTypeInName: Bool = false,
         includeParametersInName: Bool = false,
         ignoreParametersInReferences: Bool = false) throws {
        
        name = dependency.dependencyName
        type = dependency.type
        scope = dependency.configuration.scope
        self.includeTypeInName = includeTypeInName
        self.includeParametersInName = includeParametersInName
        
        switch dependency.kind {
        case .reference where ignoreParametersInReferences == false,
             .registration:
            let dependencyContainer = try dependencyGraph.dependencyContainer(for: dependency)
            parameters = dependencyContainer.parameters
        case .reference,
             .parameter:
            parameters = []
        }
    }
    
    private lazy var disambiguationHash: String? = {
        var desambiguationString = String()
        if includeParametersInName {
            desambiguationString += parameters.map { parameter in
                parameter.dependencyName + parameter.type.anyType.toTypeName
            }.joined()
        }
        if includeTypeInName {
            desambiguationString += type.anyType.toTypeName
        }
        guard desambiguationString.isEmpty == false else {
            return nil
        }
        return sha(desambiguationString)
    }()
    
    lazy var declarationName = "\(name)\(disambiguationHash.flatMap { "_\($0)" } ?? String())"
    lazy var builderName = "\(declarationName)Builder"
    lazy var buildersSubcript = "_builders[\"\(declarationName)\"]"
    lazy var resolverTypeName = "\(name.typeCase)\(disambiguationHash.flatMap { "_\($0)_" } ?? String())Resolver"
    lazy var setterName = "set\(name.typeCase)\(disambiguationHash.flatMap { "_\($0)" } ?? String())"
    lazy var setterTypeName = "\(name.typeCase)\(disambiguationHash.flatMap { "_\($0)_" } ?? String())Setter"
    lazy var declarationDoubleName = "\(name)\(disambiguationHash.flatMap { "_\($0)_" } ?? String())Double"
    
    lazy var isDisambiguated = disambiguationHash != nil
    
    // MARK: - SHA
    
    private static var shaCache = [String: String]()
    
    private func sha(_ string: String) -> String {
        if let value = MetaDependencyDeclaration.shaCache[string] {
            return value
        }
        let value = _sha(string)
        MetaDependencyDeclaration.shaCache[string] = value
        return value
    }
    
    private func _sha(_ string: String) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        let data = string.data(using: .utf8)!
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).map { String(format: "%02hhx", $0) }.joined()
    }
    
    // MARK: - Hashable
    
    static func == (lhs: MetaDependencyDeclaration, rhs: MetaDependencyDeclaration) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.disambiguationHash == rhs.disambiguationHash else { return false }
        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(disambiguationHash)
    }
}

// MARK: - Weaver File

private final class MetaWeaverFile {

    private let dependencyGraph: DependencyGraph
    
    private let inspector: Inspector
    
    private let version: String
    
    private let testableImports: [String]?

    private let swiftlintDisableAll: Bool
    
    private let importFilter: SwiftGenerator.ImportFilter
    
    // Pre computed data
    
    private let declarations: Set<MetaDependencyDeclaration>
    private let orderedDeclarations: [MetaDependencyDeclaration]

    private var setterDeclarations = [MetaDependencyDeclaration]()
    private var doesSupportObjcByDeclaration = [MetaDependencyDeclaration: Bool]()
    private var isParameterByDeclaration = [MetaDependencyDeclaration: Bool]()
    private var isPropertyWrapperAnnotationByDeclaration = [MetaDependencyDeclaration: Bool]()
    private var isEscapingByDeclaration = [MetaDependencyDeclaration: Bool]()
    
    private lazy var doesSupportObjc = dependencyGraph.dependencies.contains { $0.configuration.doesSupportObjc }

    // Cached data
    
    private var inputReferencesCache = [ObjectIdentifier: [Dependency]]()
    private var resolvedDeclarationsBySourceCache = [InspectorCacheIndex: [(source: ConcreteType?, declaration: MetaDependencyDeclaration)]]()
    private var containsAmbiguousDeclarationsCache = [ObjectIdentifier: Bool]()
    
    init(_ dependencyGraph: DependencyGraph,
         _ inspector: Inspector,
         _ version: String,
         _ testableImports: [String]?,
         _ swiftlintDisableAll: Bool,
         _ importFilter: @escaping SwiftGenerator.ImportFilter) throws {
        
        self.dependencyGraph = dependencyGraph
        self.inspector = inspector
        self.version = version
        self.testableImports = testableImports
        self.swiftlintDisableAll = swiftlintDisableAll
        self.importFilter = importFilter
        
        let desambiguatedDeclarations = try MetaWeaverFile.desambiguatedDeclarations(from: dependencyGraph)
        declarations = desambiguatedDeclarations
        orderedDeclarations = desambiguatedDeclarations.sorted { $0.declarationName < $1.declarationName }
        
        setterDeclarations = try dependencyGraph.dependencies.reduce(into: Set<MetaDependencyDeclaration>()) { declarations, dependency in
            guard dependency.kind == .registration && dependency.configuration.setter else { return }
            let declaration = try self.declaration(for: dependency)
            declarations.insert(declaration)
        }.sorted { lhs, rhs in
            lhs.setterTypeName < rhs.setterTypeName
        }
        
        for dependency in dependencyGraph.dependencies {
            let declaration = try self.declaration(for: dependency)
            if dependency.configuration.doesSupportObjc {
                doesSupportObjcByDeclaration[declaration] = true
            }
            let isParameter = isParameterByDeclaration[declaration] ?? true
            isParameterByDeclaration[declaration] = isParameter && dependency.kind == .parameter
            if dependency.annotationStyle == .propertyWrapper {
                isPropertyWrapperAnnotationByDeclaration[declaration] = true
            }
            if dependency.configuration.escaping || (dependency.type.anyType.isClosure && dependency.kind == .parameter) {
                isEscapingByDeclaration[declaration] = true
            }
        }
    }
    
    static func header(version: String, swiftlintDisableAll: Bool) -> [Comment] {
        return [
            (swiftlintDisableAll ? .comment("swiftlint:disable all") : nil),
            .documentation("This file is generated by Weaver \(version)"),
            .documentation("DO NOT EDIT!")
        ].compactMap { $0 }
    }
    
    // MARK: - Main File

    func meta() throws -> Meta.File {
        return File(name: "main-file")
            .adding(members: MetaWeaverFile.header(version: version, swiftlintDisableAll: swiftlintDisableAll))
            .adding(imports: dependencyGraph.imports.filter(importFilter).sorted().map { Import(name: $0) })
            .adding(members: try body())
    }
    
    private func body() throws -> [FileBodyMember] {
        return try [
            [
                EmptyLine(),
                mainDependencyContainer()
            ],
            resolvers(),
            [
                EmptyLine(),
                resolversImplementationExtension()
            ],
            setters(),
            [
                EmptyLine(),
                settersImplementationExtension()
            ],
            dependencyResolvers(),
            inputDependencyResolvers(),
            dependencyResolverProxies(),
            publicDependencyInitExtensions(),
            propertyWrappers(),
            providerClassAndFunctions()
        ].flatMap { $0 }
    }
    
    // MARK: - Tests File

    func metaTests() throws -> Meta.File {
        let imports = dependencyGraph.imports.subtracting(testableImports ?? [])

        return File(name: "tests-file")
            .adding(members: MetaWeaverFile.header(version: version, swiftlintDisableAll: swiftlintDisableAll))
            .adding(imports: imports.filter(importFilter).sorted().map { Import(name: $0) })
            .adding(imports: testableImports?.sorted().map { Import(name: $0, testable: true) } ?? [])
            .adding(members: try bodyTests())
    }
    
    private func bodyTests() throws -> [FileBodyMember] {
        return try [
            EmptyLine(),
            mainDependencyResolverStub(),
            EmptyLine(),
            resolversStubImplementationExtension(),
            EmptyLine(),
            settersStubImplementationExtension()
        ]
    }
}

// MARK: - MainDependencyContainer

private extension MetaWeaverFile {
    
    func mainDependencyContainer() throws -> Type {
        return Type(identifier: .mainDependencyContainer)
            .with(objc: doesSupportObjc)
            .adding(inheritedType: doesSupportObjc ? .nsObject : nil)
            .adding(member: EmptyLine())
            .adding(member: Property(variable: Variable(name: "provider").with(immutable: true).with(type: .provider)).with(accessLevel: .private))
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                .with(accessLevel: .fileprivate)
                .adding(parameter: FunctionParameter(name: "provider", type: .provider).with(defaultValue: TypeIdentifier.provider.reference | .call()))
                .adding(members: [
                    Assignment(variable: Reference.named(.`self`) + .named("provider"), value: Reference.named("provider")),
                    (doesSupportObjc ? Reference.named(.super) + .named("init") | .call() : .none)
                ])
            )
            .adding(member: dependencyGraph.hasPropertyWrapperAnnotations ? PlainCode(code: """

private static var _dynamicResolvers = [Any]()
private static var _dynamicResolversLock = NSRecursiveLock()

fileprivate static func _popDynamicResolver<Resolver>(_ resolverType: Resolver.Type) -> Resolver {
    guard let dynamicResolver = _dynamicResolvers.removeFirst() as? Resolver else {
        \(TypeIdentifier.mainDependencyContainer.swiftString).fatalError()
    }
    return dynamicResolver
}

static func _pushDynamicResolver<Resolver>(_ resolver: Resolver) {
    _dynamicResolvers.append(resolver)
}
""") : nil)
            .adding(members: dependencyGraph.hasPropertyWrapperAnnotations ? [
                EmptyLine(),
                Type(identifier: TypeIdentifier(name: "Scope"))
                    .with(kind: .enum(indirect: false))
                    .adding(members: Scope.allCases.map { Case(name: $0.rawValue) }),
                EmptyLine(),
                Type(identifier: TypeIdentifier(name: "Platform"))
                    .with(kind: .enum(indirect: false))
                    .adding(members: Platform.allCases.map { Case(name: $0.rawValue) }),
                EmptyLine(),
                Type(identifier: TypeIdentifier(name: "DependencyKind"))
                    .with(kind: .enum(indirect: false))
                    .adding(members: Dependency.Kind.allCases.map { Case(name: $0.rawValue) }),
            ] : [])
            .adding(members: try resolversImplementation())
            .adding(members: settersImplementation())
            .adding(members: try dependencyResolverCopyMethods())
    }
    
    func propertyWrappers() throws -> [FileBodyMember] {
        return declarations.reduce(into: Set<Int>()) { parametersCounts, declaration in
            guard isPropertyWrapperAnnotationByDeclaration[declaration] ?? false else { return }
            parametersCounts.insert(declaration.parameters.count)
        }.sorted().flatMap { parameterCount -> [FileBodyMember] in
            
            let typeID = TypeIdentifier(name: "Weaver\(parameterCount == 0 ? "" : "P\(parameterCount)")")

            let resolverTypealias = TypeAlias(
                identifier: TypeAliasIdentifier(name: "Resolver"),
                value: TypeIdentifier(name: .custom(
                    "(\((1..<parameterCount+1).map { "P\($0)" }.joined(separator: ", "))) -> \(TypeIdentifier.abstractType.swiftString)"
                ))
            )
            
            let wrappedValueType: TypeIdentifier
            if parameterCount == 0 {
                wrappedValueType = .abstractType
            } else {
                wrappedValueType = .resolver
            }
            
            let kindFunctionParameter = FunctionParameter(
                alias: "_",
                name: "kind",
                type: TypeIdentifier(name: "\(TypeIdentifier.mainDependencyContainer.swiftString).DependencyKind")
            )
            
            let initFunctionParameters = [
                FunctionParameter(name: "scope", type: TypeIdentifier(name: "\(TypeIdentifier.mainDependencyContainer.swiftString).Scope"))
                    .with(defaultValue: +Reference.named("container")),
                FunctionParameter(name: "setter", type: .bool).with(defaultValue: Value.bool(false)),
                FunctionParameter(name: "escaping", type: .bool).with(defaultValue: Value.bool(false)),
                FunctionParameter(name: "builder", type: .optional(wrapped: .any))
                    .with(defaultValue: Value.nil),
                FunctionParameter(name: "objc", type: .bool).with(defaultValue: Value.bool(false)),
                FunctionParameter(
                    name: "platforms",
                    type: .array(element: TypeIdentifier(name: "\(TypeIdentifier.mainDependencyContainer.swiftString).Platform"))
                ).with(defaultValue: Value.array([]))
            ]

            let type = Type(identifier: typeID)
                .with(kind: .struct)
                .adding(genericParameter: GenericParameter(name: "ConcreteType"))
                .adding(genericParameter: GenericParameter(name: "AbstractType"))
                .adding(genericParameters: (1..<parameterCount+1).map { GenericParameter(name: "P\($0)") })
                .adding(member: EmptyLine())
                .adding(member: resolverTypealias)
                .adding(member: Property(variable: Variable.resolver)
                    .with(value: TypeIdentifier.mainDependencyContainer.reference + .named("_popDynamicResolver") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named(resolverTypealias.identifier.swiftString) + .named(.`self`)))
                    )
                ))
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .adding(parameter: kindFunctionParameter)
                    .adding(parameter: FunctionParameter(name: "type", type: TypeIdentifier(name: "ConcreteType.Type")))
                    .adding(parameters: initFunctionParameters)
                    .adding(member: Comment.comment("no-op"))
                )
                .adding(member: EmptyLine())
                .adding(member: ComputedProperty(variable: Variable(name: "wrappedValue")
                    .with(type: wrappedValueType))
                    .adding(member: Return(value: Variable.resolver.reference | (parameterCount == 0 ? .call() : .none)))
                )
            
            let `extension` = Extension(type: typeID)
                .adding(constraint: TypeIdentifier.concreteType.reference == TypeIdentifier.void.reference)
                .adding(member: Function(kind: .`init`)
                    .adding(parameter: kindFunctionParameter)
                    .adding(parameters: initFunctionParameters)
                    .adding(member: Comment.comment("no-op"))
                )
            
            return [
                EmptyLine(),
                PlainCode(code: """
                @propertyWrapper
                \(MetaCode(meta: type))
                """),
                EmptyLine(),
                `extension`
            ]
        }
    }
    
    func resolversImplementation() throws -> [TypeBodyMember] {

        let builderGetters = orderedDeclarations.flatMap { declaration -> [TypeBodyMember] in
            var members: [TypeBodyMember] = [EmptyLine()]

            members += [
                ComputedProperty(variable: Variable(name: declaration.builderName)
                    .with(type: .builder(of: declaration.type.typeID)))
                    .with(accessLevel: .private)
                    .adding(member: Return(value: .provider + .named("getBuilder") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Value.string(declaration.declarationName)))
                        .adding(parameter: TupleParameter(value: declaration.type.typeID.reference + .named(.`self`)))
                    )))
            ]

            return members
        }

        let getters = try orderedDeclarations.flatMap { declaration -> [TypeBodyMember] in
            var members: [TypeBodyMember] = [EmptyLine()]
            
            if declaration.parameters.isEmpty {
                members += [
                    ComputedProperty(variable: Variable(name: declaration.declarationName)
                        .with(type: declaration.type.typeID))
                        .adding(member: Return(value: Reference.named(declaration.builderName) | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.nil))
                        )))
                ]
            } else {
                members += [
                    Function(kind: .named(declaration.declarationName))
                        .with(resultType: declaration.type.typeID)
                        .adding(parameters: try declaration.parameters.map { parameter in
                            let declaration = try self.declaration(for: parameter)
                            return FunctionParameter(name: parameter.dependencyName, type: parameter.type.typeID)
                                .with(escaping: isEscapingByDeclaration[declaration] ?? false)
                        })
                        .adding(member: Return(value: Reference.named(declaration.builderName) | .block(FunctionBody()
                            .adding(context: declaration.parameters.compactMap { parameter in
                                guard parameter.configuration.scope == .weak else { return nil }
                                return FunctionBodyContext(name: parameter.dependencyName, kind: .weak)
                            })
                            .adding(parameter: FunctionBodyParameter(name: Variable(name: "provider").name))
                            .adding(members: try declaration.parameters.map { parameter in
                                let declaration = try self.declaration(for: parameter)

                                let parameterProviderReference: Reference
                                if parameter.configuration.scope == .weak {
                                    parameterProviderReference = .weakOptionalValueBuilder(value: .named(parameter.dependencyName))
                                } else {
                                    parameterProviderReference = .valueBuilder(value: .named(parameter.dependencyName))
                                }

                                return Reference.provider + .named("setBuilder") | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Value.string(declaration.declarationName)))
                                    .adding(parameter: TupleParameter(value: Value.reference(parameterProviderReference)))
                                )
                            })
                        )))
                ]
            }
            
            return members
        }

        return builderGetters + getters
    }

    func resolvers() throws -> [FileBodyMember] {
        return try orderedDeclarations.flatMap { declaration -> [FileBodyMember] in
            return [
                EmptyLine(),
                Type(identifier: TypeIdentifier(name: declaration.resolverTypeName))
                    .with(objc: doesSupportObjcByDeclaration[declaration] ?? false)
                    .with(kind: .protocol)
                    .adding(inheritedType: .anyObject)
                    .adding(member: declaration.parameters.isEmpty ?
                        ProtocolProperty(name: declaration.declarationName, type: declaration.type.typeID) :
                        ProtocolFunction(name: declaration.declarationName)
                            .with(resultType: declaration.type.typeID)
                            .adding(parameters: try declaration.parameters.map { parameter in
                                let declaration = try self.declaration(for: parameter)
                                return FunctionParameter(name: parameter.dependencyName, type: parameter.type.typeID)
                                    .with(escaping: isEscapingByDeclaration[declaration] ?? false)
                            })
                    )
            ]
        }
    }
    
    func resolversImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyContainer)
            .adding(inheritedTypes: orderedDeclarations.map { declaration in
                TypeIdentifier(name: declaration.resolverTypeName)
            })
    }
    
    func settersImplementation() -> [TypeBodyMember] {
        return setterDeclarations.flatMap { declaration -> [TypeBodyMember] in
            let parameterProviderReference: Reference
            if declaration.scope == .weak {
                parameterProviderReference = .weakOptionalValueBuilder(value: .named(declaration.name))
            } else {
                parameterProviderReference = .valueBuilder(value: .named("value"))
            }
            return [
                EmptyLine(),
                Function(kind: .named(declaration.setterName))
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: declaration.type.typeID))
                    .adding(member: Reference.provider + .named("setBuilder") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Value.string(declaration.declarationName)))
                        .adding(parameter: TupleParameter(value: Value.reference(parameterProviderReference)))
                    ))
            ]
        }
    }
    
    func setters() -> [FileBodyMember] {
        return setterDeclarations.flatMap { declaration -> [FileBodyMember] in
            return [
                EmptyLine(),
                Type(identifier: TypeIdentifier(name: declaration.setterTypeName))
                    .with(kind: .protocol)
                    .with(objc: doesSupportObjcByDeclaration[declaration] ?? false)
                    .adding(inheritedType: .anyObject)
                    .adding(member: ProtocolFunction(name: declaration.setterName)
                        .adding(parameter: FunctionParameter(alias: "_", name: "value", type: declaration.type.typeID))
                    )
            ]
        }
    }
    
    func settersImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyContainer)
            .adding(inheritedTypes: setterDeclarations.map { declaration in
                TypeIdentifier(name: declaration.setterTypeName)
            })
    }
    
    func dependencyResolvers() throws -> [FileBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [FileBodyMember] in
            switch dependencyContainer.declarationSource {
            case .type:
                let resolverTypeIDs = try dependencyContainer.dependencies.orderedValues.map { dependency in
                    TypeIdentifier(name: try declaration(for: dependency, ignoreParametersInReferences: true).resolverTypeName)
                }
                let setterTypeIDs = try dependencyContainer.registrations.compactMap { registration -> TypeIdentifier? in
                    guard registration.configuration.setter else { return nil }
                    return TypeIdentifier(name: try declaration(for: registration, ignoreParametersInReferences: true).setterTypeName)
                }
                guard let andTypeIDs = TypeIdentifier.and(resolverTypeIDs + setterTypeIDs) else { return [] }

                let typeIdentifier = try containsAmbiguousDeclarations(in: dependencyContainer)
                ? dependencyContainer.type.internalDependencyResolverTypeID
                : dependencyContainer.type.dependencyResolverTypeID

                let name = typeIdentifier.name
                let typeComponents = typeIdentifier.typeComponents
                let typeAlias: FileBodyMember

                if typeComponents.count == 1 {
                    typeAlias = TypeAlias(
                        identifier: TypeAliasIdentifier(name: name),
                        value: andTypeIDs
                    )
                } else {
                    let extensionName = typeComponents.dropLast().joined(separator: ".")
                    typeAlias = Extension(name: extensionName)
                        .adding(member: TypeAlias(
                            identifier: TypeAliasIdentifier(name: typeComponents[typeComponents.count-1]),
                            value: andTypeIDs
                        )
                    )
                }

                return [
                    EmptyLine(),
                    typeAlias
                ]
                
            case .registration,
                 .reference:
                return []
            }
        }
    }
    
    func inputDependencyResolvers() throws -> [FileBodyMember] {
        return try dependencyGraph.dependencies.reduce(into: [ConcreteType: Set<MetaDependencyDeclaration>]()) { declarationsByTarget, dependency in
            guard dependency.kind == .registration && dependency.configuration.customBuilder != nil else { return }
            
            let target = try dependencyGraph.dependencyContainer(for: dependency)
            guard target.declarationSource != .type else { return }

            let source = try dependencyGraph.dependencyContainer(for: dependency.source)
            let inputDeclarations = Set(try source.dependencies.orderedValues.lazy.map { try declaration(for: $0) })
            
            if var declarations = declarationsByTarget[target.type] {
                declarations.formIntersection(inputDeclarations)
                declarationsByTarget[target.type] = declarations
            } else {
                declarationsByTarget[target.type] = inputDeclarations
            }
        }.lazy.sorted { lhs, rhs in
            lhs.key.description < rhs.key.description
        }.flatMap { (target, declarations) -> [FileBodyMember] in
            guard declarations.isEmpty == false else { return [] }
            let target = try dependencyGraph.dependencyContainer(for: target)
            let declarations = declarations.lazy.sorted { lhs, rhs in lhs.resolverTypeName < rhs.resolverTypeName }

            let typeComponents = target.type.inputDependencyResolverTypeID.typeComponents
            let typeAlias: FileBodyMember

            if typeComponents.count == 1 {
                typeAlias = TypeAlias(
                    identifier: TypeAliasIdentifier(name: target.type.inputDependencyResolverTypeID.name),
                    value: TypeIdentifier.and(declarations.map { declaration in
                        TypeIdentifier(name: declaration.resolverTypeName)
                    })!
                )
            } else {
                let extensionName = typeComponents.dropLast().joined(separator: ".")
                typeAlias = Extension(name: extensionName)
                    .adding(member: TypeAlias(
                        identifier: TypeAliasIdentifier(name: typeComponents[typeComponents.count-1]),
                        value: TypeIdentifier.and(declarations.map { declaration in
                            TypeIdentifier(name: declaration.resolverTypeName)
                        })!
                    )
                )
            }

            return [
                EmptyLine(),
                typeAlias
            ]
        }
    }
    
    func dependencyResolverCopyMethods() throws -> [TypeBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap {
            try dependencyResolverCopyMethod(for: $0)
        }
    }
    
    func dependencyResolverCopyMethod(for dependencyContainer: DependencyContainer, publicInterface: Bool = false) throws -> [TypeBodyMember] {
        guard dependencyContainer.declarationSource == .type else { return [] }
        
        let inputReferences: [Dependency]
        if publicInterface {
            inputReferences = try dependencyContainer.parameters + self.inputReferences(of: dependencyContainer)
        } else {
            inputReferences = try self.inputReferences(of: dependencyContainer)
        }
        let containsAmbiguousDeclarations = try self.containsAmbiguousDeclarations(in: dependencyContainer)
        let containsDeclarationBasedOnSource = try self.containsDeclarationBasedOnSource(in: dependencyContainer)

        let selfReferenceDeclarations = try dependencyContainer.references.reduce(into: Set<MetaDependencyDeclaration>()) { declarations, reference in
            guard try dependencyGraph.isSelfReference(reference) else { return }
            let declaration = try self.declaration(for: reference)
            declarations.insert(declaration)
        }
        
        let accessLevel: Meta.AccessLevel =
            (inputReferences.isEmpty && dependencyContainer.parameters.isEmpty) || publicInterface ? .fileprivate : .private

        let functionParameterValues: [MetaDependencyDeclaration] = publicInterface ? try inputReferences.compactMap { reference in
            let declaration = try self.declaration(for: reference)
            guard selfReferenceDeclarations.contains(declaration) == false else { return nil }
            return declaration
        } : []

        let hasInputDependencies: Bool = dependencyContainer.registrations.reduce(false) { boolResult, registration in
            if boolResult { return true }
            guard let declaration = try? self.declaration(for: registration) else { return false }
            guard let target = try? dependencyGraph.dependencyContainer(for: registration) else { return false }
            return target.dependencies.isEmpty == false ||
                registration.configuration.customBuilder != nil ||
                declaration.parameters.isEmpty == false
        }

        let hasSetter = dependencyContainer.dependencies.orderedValues.contains { $0.configuration.setter == true }
        let hasParameters = dependencyContainer.parameters.isEmpty == false
        let useReference = hasSetter || hasParameters

        let inputProviderReference: Assignment?
        if hasInputDependencies {
            if useReference {
                inputProviderReference = Assignment(variable: Variable(name: "_inputProvider"), value: Variable._self.reference + .provider)
            } else {
                inputProviderReference = Assignment(variable: Variable(name: "_inputProvider"), value: Variable._self.reference + .provider + .named("copy") | .call())
            }
        } else {
            inputProviderReference = nil
        }

        let copyAssignments: [FunctionBodyMember] = try dependencyContainer.registrations.compactMap { registration in
            try copyAssignment(for: registration, from: dependencyContainer)
        }

        let inputReferenceAssignments: [FunctionBodyMember] = try inputReferences.flatMap { reference -> [FunctionBodyMember] in

            let declaration = try self.declaration(for: reference, ignoreParametersInReferences: true)
            guard selfReferenceDeclarations.contains(declaration) == false else { return [] }

            let assignments: (MetaDependencyDeclaration) -> [Assignment] = { resolvedDeclaration in
                let inputNames = functionParameterValues.map { $0.name }

                let isRootDependencyContainer = dependencyContainer.sources.isEmpty && publicInterface == false
                let isParameter = inputNames.contains(resolvedDeclaration.name)
                let shouldHoldSelfReference = isRootDependencyContainer || isParameter

                let providerValue: (MetaDependencyDeclaration) -> Reference = { currentDeclaration in
                    if inputNames.contains(currentDeclaration.name) {
                        if currentDeclaration.scope == .weak {
                            return .weakOptionalValueBuilder(value: .named(currentDeclaration.name))
                        } else {
                            return .valueBuilder(value: .named(currentDeclaration.name))
                        }
                    } else {
                        return (shouldHoldSelfReference ? Variable._self.reference + .none : .none) | .named(currentDeclaration.builderName)
                    }
                }

                var assignments = [Assignment(
                    variable: Reference.named(declaration.buildersSubcript),
                    value: providerValue(declaration)
                )]

                if resolvedDeclaration.declarationName != declaration.declarationName {
                    assignments += [Assignment(
                        variable: Reference.named(resolvedDeclaration.buildersSubcript),
                        value: providerValue(resolvedDeclaration)
                    )]
                }

                return assignments
            }

            if publicInterface {
                return assignments(declaration)
            } else {
                let resolvedDeclarations = try resolvedDeclarationsBySource(for: reference, in: dependencyContainer)
                if resolvedDeclarations.count > 1 {
                    return [Switch(reference: Variable.source.reference)
                        .adding(cases: resolvedDeclarations.compactMap { source, declaration in
                            guard let source = source else { return nil }
                            return SwitchCase()
                                .adding(value: Value.string(source.description))
                                .adding(members: assignments(declaration))
                        })
                        .adding(case: SwitchCase(name: .default)
                            .adding(member: TypeIdentifier.mainDependencyContainer.reference + .named("fatalError") | .call())
                        )]
                } else if let resolvedDeclaration = resolvedDeclarations.first?.declaration {
                    return assignments(resolvedDeclaration)
                } else {
                    return []
                }
            }
        }

        let requiresBuilders = copyAssignments.count > 0 || inputReferenceAssignments.count > 0

        var members: [TypeBodyMember] = [
            EmptyLine(),
            Function(kind: .named(publicInterface ?
                dependencyContainer.type.publicDependencyResolverVariable.name : dependencyContainer.type.dependencyResolverVariable.name))
                .with(accessLevel: accessLevel)
                .with(resultType: containsAmbiguousDeclarations ?
                    dependencyContainer.type.dependencyResolverProxyTypeID : dependencyContainer.type.dependencyResolverTypeID
                )
                .adding(parameter: containsDeclarationBasedOnSource && publicInterface == false ?
                    FunctionParameter(alias: "_", name: Variable.source.name, type: .string) : nil
                )
                .adding(parameters: functionParameterValues.map { declaration in
                    return FunctionParameter(name: declaration.declarationName, type: declaration.type.typeID)
                })
                .adding(member: Assignment(variable: Variable._self, value: TypeIdentifier.mainDependencyContainer.reference | .call(Tuple()
                    .adding(parameter: hasInputDependencies ? TupleParameter(name: "provider", value: Reference.provider + .named("copy") | .call()) : nil)
                )))
                .adding(member: inputProviderReference)
                .adding(member: requiresBuilders ? Assignment(variable: Variable(name: "_builders").with(immutable: false), value: Reference.named("Dictionary<String, Any>") | .call()) : nil)
                .adding(members: copyAssignments)
                .adding(members: inputReferenceAssignments)
                .adding(member: requiresBuilders ? Variable._self.reference + .provider + .named("addBuilders") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("_builders")))
                ) : nil)
                .adding(member: (hasInputDependencies && useReference == false) ? Reference.named("_inputProvider") + .named("addBuilders") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("_builders")))
                ) : nil)
                .adding(members: try dependencyContainer.registrations.compactMap { registration in
                    guard registration.configuration.setter == false else { return nil }
                    switch registration.configuration.scope {
                    case .container:
                        let declaration = try self.declaration(for: registration)
                        return Assignment(
                            variable: Reference.named("_"),
                            value: Variable._self.reference + .named(declaration.name)
                        )
                    case .lazy,
                         .weak,
                         .transient:
                        return nil
                    }
                })
                .adding(members: try dependencyContainer.dependencies.orderedValues.compactMap { dependency in
                    guard dependency.annotationStyle == .propertyWrapper else { return nil }
                    let declaration = try self.declaration(for: dependency)
                    return TypeIdentifier.mainDependencyContainer.reference + .named("_pushDynamicResolver") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: declaration.parameters.isEmpty ?
                            Reference.named("{ \(Variable._self.name).\(declaration.declarationName) }") :
                            Variable._self.reference + .named(declaration.declarationName)
                        ))
                    )
                })
                .adding(member: Return(value: containsAmbiguousDeclarations ?
                    dependencyContainer.type.dependencyResolverProxyTypeID.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Variable._self.reference))
                    ) :
                    Variable._self.reference)
                )
        ]
        
        if dependencyContainer.references.isEmpty && dependencyContainer.parameters.isEmpty {
            members += [
                EmptyLine(),
                Function(kind: .named(dependencyContainer.type.dependencyResolverVariable.name))
                    .with(resultType: containsAmbiguousDeclarations ?
                        dependencyContainer.type.dependencyResolverProxyTypeID : dependencyContainer.type.dependencyResolverTypeID
                    )
                    .with(static: true)
                    .adding(member: Assignment(
                        variable: Variable._self,
                        value: TypeIdentifier.mainDependencyContainer.reference | .call() + dependencyContainer.type.dependencyResolverVariable.reference | .call()
                    ))
                    .adding(member: Return(value: Variable._self.reference))
            ]
        } else if dependencyContainer.accessLevel.isPublic && publicInterface == false {
            members += try dependencyResolverCopyMethod(for: dependencyContainer, publicInterface: true)
        }
        
        return members
    }
    
    func copyAssignment(for registration: Dependency,
                        from dependencyContainer: DependencyContainer) throws -> Assignment? {
        
        guard registration.configuration.setter == false else { return nil }

        guard let concreteType = registration.type.concreteType else { return nil }
        let declaration = try self.declaration(for: registration)
        
        let target = try dependencyGraph.dependencyContainer(for: registration)
        let targetContainsDeclarationBasedOnSource = try containsDeclarationBasedOnSource(in: target)
        let targetContainsAmbiguousDeclarations = try containsAmbiguousDeclarations(in: target)
        let targetHasPropertyWrapperAnnotations = target.dependencies.orderedValues.contains {
            $0.annotationStyle == .propertyWrapper
        }
        
        let hasInputDependencies =
            target.dependencies.isEmpty == false ||
            registration.configuration.customBuilder != nil ||
            declaration.parameters.isEmpty == false

        let hasDeclarationParameters = declaration.parameters.isEmpty == false
        let containsAmbiguousDeclarations = try self.containsAmbiguousDeclarations(in: dependencyContainer)

        let resolverReference: Reference?
        var builderReference: Reference

        let shouldUnwrapResolverReference: Bool
        let isTypecastingAsResolver: Bool

        if let customBuilder = registration.configuration.customBuilder {
            switch target.declarationSource {
            case .type:
                resolverReference = hasInputDependencies ? Reference.named("_inputContainer") + concreteType.dependencyResolverVariable.reference | .call(Tuple()
                    .adding(parameter: targetContainsDeclarationBasedOnSource ? TupleParameter(value: Value.string(dependencyContainer.type.description)) : nil)
                ) : nil
                builderReference = .named(customBuilder) | .call(Tuple()
                    .adding(parameter: hasInputDependencies ? TupleParameter(value: Variable.__self.reference) : nil)
                )
                shouldUnwrapResolverReference = false
                isTypecastingAsResolver = false
            case .reference,
                 .registration:
                resolverReference = containsAmbiguousDeclarations ? dependencyContainer.type.dependencyResolverProxyTypeID.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("_inputContainer")))
                ) : nil
                builderReference = .named(customBuilder) | .call(Tuple()
                    .adding(parameter: TupleParameter(value:
                        (containsAmbiguousDeclarations ? Variable.__self.reference + Variable.proxySelf.reference : Reference.named("_inputContainer")) |
                        .as | target.type.inputDependencyResolverTypeID.reference
                    ))
                )
                shouldUnwrapResolverReference = containsAmbiguousDeclarations
                isTypecastingAsResolver = true
            }
        } else {
            resolverReference = hasInputDependencies ? Reference.named("_inputContainer") + concreteType.dependencyResolverVariable.reference | .call(Tuple()
                .adding(parameter: targetContainsDeclarationBasedOnSource ? TupleParameter(value: Value.string(dependencyContainer.type.description)) : nil)
            ) : nil
            builderReference = concreteType.typeID.reference | .call(Tuple()
                .adding(parameter: hasInputDependencies ? TupleParameter(
                    name: "injecting",
                    value: Variable.__self.reference
                ) : nil)
            )
            shouldUnwrapResolverReference = targetContainsAmbiguousDeclarations
            isTypecastingAsResolver = false
        }

        let hasInputContainer = resolverReference != nil || isTypecastingAsResolver
        let hasSetter = dependencyContainer.dependencies.orderedValues.contains { $0.configuration.setter == true }
        let hasParameters = dependencyContainer.parameters.isEmpty == false
        let useReference = hasSetter || hasParameters

        let functionBody = FunctionBody()
            .adding(parameter: FunctionBodyParameter(
                name: hasDeclarationParameters ? "copyParameters" : nil,
                type: .optional(wrapped: TypeIdentifier(name: "Provider.ParametersCopier"))
            ))
            .with(resultType: declaration.type.typeID)
            .adding(member: targetHasPropertyWrapperAnnotations ? PlainCode(code: """
            defer { MainDependencyContainer._dynamicResolversLock.unlock() }
            MainDependencyContainer._dynamicResolversLock.lock()
            """) : nil)
            .adding(member: hasInputContainer ?
                Assignment(variable: Variable(name: "_inputContainer"), value: TypeIdentifier.mainDependencyContainer.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "provider", value: Reference.named("_inputProvider") | (useReference ? .none + .named("copy") | .call() : .none)))
                ))
            : nil)
            .adding(member: resolverReference.flatMap {
                Assignment(variable: Variable.__self, value: $0)
            })
            .adding(member: hasDeclarationParameters ? .named("copyParameters") | .unwrap | .call(Tuple()
                .adding(parameter: TupleParameter(
                    value: Reference.named("(") | Variable.__self.reference |
                        (shouldUnwrapResolverReference ? +Variable.proxySelf.reference : .none) |
                        .named(" as! ") |
                        TypeIdentifier.mainDependencyContainer.reference | Reference.named(")") + Reference.provider
                ))
            ) : nil)
            .adding(member: Return(value: builderReference))

        let builderFunction: Reference
        switch registration.configuration.scope {
        case .container,
             .lazy:
            builderFunction = .lazyBuilder(body: functionBody)
        case .weak:
            builderFunction = .weakLazyBuilder(body: functionBody)
        case .transient:
            builderFunction = .block(functionBody)
        }

        return Assignment(
            variable: Reference.named(declaration.buildersSubcript),
            value: builderFunction
        )
    }
    
    func dependencyResolverProxies() throws -> [FileBodyMember] {
        
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [FileBodyMember] in
            guard try containsAmbiguousDeclarations(in: dependencyContainer) else { return [] }

            let typeComponents = dependencyContainer.type.dependencyResolverTypeID.typeComponents
            let typeProxyComponents = dependencyContainer.type.dependencyResolverProxyTypeID.typeComponents
            let typeAlias: FileBodyMember
            let typeIdentifier: TypeIdentifier

            if typeProxyComponents.count == 1 {
                typeIdentifier = dependencyContainer.type.dependencyResolverProxyTypeID
            } else {
                typeIdentifier = TypeIdentifier(name: typeProxyComponents[typeProxyComponents.count-1])
            }

            let typeDeclaration = Type(identifier: typeIdentifier)
                .with(kind: .struct)
                .adding(member: EmptyLine())
                .adding(member: Property(variable: Variable.proxySelf
                    .with(type: dependencyContainer.type.internalDependencyResolverTypeID))
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                    .adding(parameter: FunctionParameter(alias: "_", name: Variable.proxySelf.name, type: dependencyContainer.type.internalDependencyResolverTypeID))
                    .adding(member: Assignment(variable: .named(.`self`) + Variable.proxySelf.reference, value: Variable.proxySelf.reference))
                )
                .adding(members: try dependencyContainer.dependencies.orderedValues.flatMap { dependency -> [TypeBodyMember] in
                    let declaration = try self.declaration(for: dependency, ignoreParametersInReferences: true)

                    var members: [TypeBodyMember] = [EmptyLine()]
                    if declaration.parameters.isEmpty {
                        members += [
                            ComputedProperty(variable: Variable(name: declaration.name)
                                .with(type: declaration.type.typeID))
                                .adding(member: Return(value: Variable.proxySelf.reference + .named(declaration.declarationName)))
                        ]
                    } else {
                        members += [
                            Function(kind: .named(declaration.name))
                                .with(resultType: declaration.type.typeID)
                                .adding(parameters: declaration.parameters.map { parameter in
                                    FunctionParameter(name: parameter.dependencyName, type: parameter.type.typeID)
                                })
                                .adding(member: Return(value: Variable.proxySelf.reference + .named(declaration.declarationName) | .call(Tuple()
                                    .adding(parameters: declaration.parameters.map { parameter in
                                        return TupleParameter(name: parameter.dependencyName, value: Reference.named(parameter.dependencyName))
                                    })
                                )))
                        ]
                    }

                    return members
                })

            let typeOrExtension: FileBodyMember

            if typeComponents.count == 1 {
                typeAlias = TypeAlias(
                    identifier: TypeAliasIdentifier(name: dependencyContainer.type.dependencyResolverTypeID.name),
                    value: TypeIdentifier(name: dependencyContainer.type.dependencyResolverProxyTypeID.name)
                )
                typeOrExtension = typeDeclaration
            } else {
                let extensionName = typeComponents.dropLast().joined(separator: ".")
                typeAlias = Extension(name: extensionName)
                    .adding(member: TypeAlias(
                        identifier: TypeAliasIdentifier(name: typeComponents[typeComponents.count-1]),
                        value: TypeIdentifier(name: dependencyContainer.type.dependencyResolverProxyTypeID.name)
                    )
                )

                typeOrExtension = Extension(name: extensionName)
                    .adding(member: EmptyLine())
                    .adding(member: typeDeclaration)
            }

            return [
                EmptyLine(),
                typeOrExtension,
                EmptyLine(),
                typeAlias
            ]
        }
    }

    func publicDependencyInitExtensions() throws -> [FileBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [FileBodyMember] in
            guard dependencyContainer.declarationSource == .type else { return [] }
            guard dependencyContainer.accessLevel.isPublic else { return [] }
            let parameters = try dependencyContainer.parameters + inputReferences(of: dependencyContainer)
            let dependencyResolverVariable = parameters.isEmpty ?
                dependencyContainer.type.dependencyResolverVariable : dependencyContainer.type.publicDependencyResolverVariable
            return [
                EmptyLine(),
                Extension(type: dependencyContainer.type.typeID.with(genericParameters: []))
                    .adding(member: Function(kind: .`init`(convenience: true, optional: false))
                        .with(accessLevel: .public)
                        .adding(parameters: try parameters.map { dependency in
                            let declaration = try self.declaration(for: dependency)
                            return FunctionParameter(name: declaration.declarationName, type: declaration.type.typeID)
                        })
                        .adding(member: Assignment(
                            variable: Variable._self,
                            value: TypeIdentifier.mainDependencyContainer.reference | .call()
                        ))
                        .adding(member: Assignment(
                            variable: Variable.__self,
                            value: Variable._self.reference + dependencyResolverVariable.reference | .call(Tuple()
                                .adding(parameters: try parameters.map { dependency in
                                    let declaration = try self.declaration(for: dependency)
                                    return TupleParameter(name: declaration.declarationName, value: Reference.named(declaration.declarationName))
                                })
                            )
                        ))
                        .adding(member: Reference.named(.`self`) + .named(.`init`) | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "injecting", value: Variable.__self.reference))
                        ))
                    )
            ]
        }
    }
}

// MARK: - MainDependencyResolverStub

private extension MetaWeaverFile {
    
    func mainDependencyResolverStub() throws -> Type {
        return Type(identifier: .mainDependencyResolverStub)
            .with(kind: .class(final: false))
            .with(objc: doesSupportObjc)
            .adding(inheritedType: doesSupportObjc ? .nsObject : nil)
            .adding(members: resolversStubImplementation())
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                .with(override: doesSupportObjc)
            )
            .adding(members: settersStubImplementation())
            .adding(members: try dependencyBuilders())
    }
    
    func resolversStubImplementation() -> [TypeBodyMember] {
        return orderedDeclarations.flatMap { declaration -> [TypeBodyMember] in
            let doubleVariable = Variable(name: declaration.declarationDoubleName)
            let isParameter = isParameterByDeclaration[declaration] ?? false
            if isParameter {
                guard let concreteType = declaration.type.concreteType else { return [] }
                return [
                    EmptyLine(),
                    PlainCode(code: """
                    var \(doubleVariable.name): \(concreteType.typeID.swiftString)\(concreteType.value.isOptional ? " = nil" : "!")
                    """),
                    ComputedProperty(variable: Variable(name: declaration.declarationName)
                        .with(type: declaration.type.typeID))
                        .adding(member: Return(value: doubleVariable.reference))
                ]
            } else {
                var members: [TypeBodyMember] = [
                    EmptyLine(),
                    Property(variable: doubleVariable
                        .with(immutable: false))
                        .with(value: Reference.named("\(declaration.type.typeID.swiftString)Double") | .call()),
                ]
                
                if declaration.parameters.isEmpty {
                    members += [
                        ComputedProperty(variable: Variable(name: declaration.declarationName)
                            .with(type: declaration.type.typeID))
                            .adding(member: Return(value: doubleVariable.reference))
                    ]
                } else {
                    members += [
                        Function(kind: .named(declaration.declarationName))
                            .with(resultType: declaration.type.typeID)
                            .adding(parameters: declaration.parameters.map { parameter in
                                FunctionParameter(name: parameter.dependencyName, type: parameter.type.typeID)
                            })
                            .adding(member: Return(value: doubleVariable.reference))
                    ]
                }
                
                return members
            }
        }
    }
    
    func resolversStubImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyResolverStub)
            .adding(inheritedTypes: orderedDeclarations.map { declaration in
                TypeIdentifier(name: declaration.resolverTypeName)
            })
    }
    
    func settersStubImplementation() -> [TypeBodyMember] {
        return setterDeclarations.flatMap { declaration -> [TypeBodyMember] in
            [
                EmptyLine(),
                Function(kind: .named(declaration.setterName))
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: declaration.type.typeID))
                    .adding(member: Comment.comment("no-op"))
            ]
        }
    }
    
    func settersStubImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyResolverStub)
            .adding(inheritedTypes: setterDeclarations.map { declaration in
                TypeIdentifier(name: declaration.setterTypeName)
            })
    }
    
    func dependencyBuilders() throws -> [TypeBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [TypeBodyMember] in
            guard dependencyContainer.declarationSource == .type else { return [] }
            guard dependencyContainer.parameters.isEmpty == false || dependencyContainer.references.isEmpty == false else { return [] }
            let containsAmbiguousDeclarations = try self.containsAmbiguousDeclarations(in: dependencyContainer)
            return [
                EmptyLine(),
                Function(kind: .named(dependencyContainer.type.dependencyBuilderVariable.name))
                    .adding(parameters: dependencyContainer.parameters.map { parameter in
                        FunctionParameter(name: parameter.dependencyName, type: parameter.type.typeID)
                    })
                    .with(resultType: dependencyContainer.type.typeID)
                    .adding(members: try dependencyContainer.parameters.map { parameter in
                        let declaration = try self.declaration(for: parameter)
                        let doubleVariable = Variable(name: declaration.declarationDoubleName)
                        return Assignment(
                            variable: doubleVariable.reference,
                            value: Reference.named(parameter.dependencyName)
                        )
                    })
                    .adding(members: try dependencyContainer.dependencies.orderedValues.compactMap { dependency in
                        guard dependency.annotationStyle == .propertyWrapper else { return nil }
                        let declaration = try self.declaration(for: dependency)
                        return TypeIdentifier.mainDependencyContainer.reference + .named("_pushDynamicResolver") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: declaration.parameters.isEmpty ?
                                Reference.named("{ self.\(declaration.declarationName) }") :
                                Variable._self.reference + .named(declaration.declarationName)
                            ))
                        )
                    })
                    .adding(member: Return(value: dependencyContainer.type.typeID.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(
                            name: "injecting",
                            value: containsAmbiguousDeclarations == false ?
                                Reference.named(.`self`) :
                                dependencyContainer.type.dependencyResolverProxyTypeID.reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Reference.named(.`self`)))
                                )
                        ))
                    )))
            ]
        }
    }

    func providerClassAndFunctions() throws -> [FileBodyMember] {
        return [
            EmptyLine(),
            PlainCode(code: """
            // MARK: - Fatal Error

            extension MainDependencyContainer {

                static var onFatalError: (String, StaticString, UInt) -> Never = { message, file, line in
                    Swift.fatalError(message, file: file, line: line)
                }

                fileprivate static func fatalError(file: StaticString = #file, line: UInt = #line) -> Never {
                    onFatalError("Invalid memory graph. This is never suppose to happen. Please file a ticket at https://github.com/scribd/Weaver", file, line)
                }
            }

            // MARK: - Provider

            private final class Provider {

                typealias ParametersCopier = (Provider) -> Void
                typealias Builder<T> = (ParametersCopier?) -> T

                private(set) var builders: Dictionary<String, Any>

                init(builders: Dictionary<String, Any> = [:]) {
                    self.builders = builders
                }
            }

            private extension Provider {

                func addBuilders(_ builders: Dictionary<String, Any>) {
                    builders.forEach { key, value in
                        self.builders[key] = value
                    }
                }

                func setBuilder<T>(_ name: String, _ builder: @escaping Builder<T>) {
                    builders[name] = builder
                }

                func getBuilder<T>(_ name: String, _ type: T.Type) -> Builder<T> {
                    guard let builder = builders[name] as? Builder<T> else {
                        return Provider.fatalBuilder()
                    }
                    return builder
                }

                func copy() -> Provider {
                    return Provider(builders: builders)
                }
            }

            private extension Provider {

                static func valueBuilder<T>(_ value: T) -> Builder<T> {
                    return { _ in
                        return value
                    }
                }

                static func weakOptionalValueBuilder<T>(_ value: Optional<T>) -> Builder<Optional<T>> where T: AnyObject {
                    return { [weak value] _ in
                        return value
                    }
                }

                static func lazyBuilder<T>(_ builder: @escaping Builder<T>) -> Builder<T> {
                    var _value: T?
                    return { copyParameters in
                        if let value = _value {
                            return value
                        }
                        let value = builder(copyParameters)
                        _value = value
                        return value
                    }
                }

                static func weakLazyBuilder<T>(_ builder: @escaping Builder<T>) -> Builder<T> where T: AnyObject {
                    weak var _value: T?
                    return { copyParameters in
                        if let value = _value {
                            return value
                        }
                        let value = builder(copyParameters)
                        _value = value
                        return value
                    }
                }

                static func fatalBuilder<T>() -> Builder<T> {
                    return { _ in
                        MainDependencyContainer.fatalError()
                    }
                }
            }
            """)
        ]
    }
}

// MARK: - Graph Transformations

private extension MetaWeaverFile {
    
    static func desambiguatedDeclarations(from dependencyGraph: DependencyGraph) throws -> Set<MetaDependencyDeclaration> {

        let dependenciesByDeclaration: [MetaDependencyDeclaration: [Dependency]] =
            try dependencyGraph.dependencies.reduce(into: [:]) { dependenciesByDeclaration, dependency in
                let declaration = try MetaDependencyDeclaration(for: dependency, in: dependencyGraph)
                var dependencies = dependenciesByDeclaration[declaration] ?? []
                dependencies.append(dependency)
                dependenciesByDeclaration[declaration] = dependencies
            }
        
        return Set(try dependenciesByDeclaration.lazy.flatMap { declaration, dependencies -> Set<MetaDependencyDeclaration> in
            let declarations = Set(try dependencies.lazy.map {
                try MetaDependencyDeclaration(for: $0, in: dependencyGraph, includeTypeInName: true, includeParametersInName: true)
            })

            if declarations.count == 1 {
                return Set([declaration])
            } else {
                return declarations
            }
        })
    }
    
    func declaration(for dependency: Dependency, ignoreParametersInReferences: Bool = false) throws -> MetaDependencyDeclaration {
        let declaration = try MetaDependencyDeclaration(for: dependency, in: dependencyGraph, includeTypeInName: true, includeParametersInName: true, ignoreParametersInReferences: ignoreParametersInReferences)
        if declarations.contains(declaration) {
            return declaration
        } else {
            let declaration = try MetaDependencyDeclaration(for: dependency, in: dependencyGraph, includeTypeInName: true, ignoreParametersInReferences: ignoreParametersInReferences)
            if declarations.contains(declaration) {
                return declaration
            } else {
                return try MetaDependencyDeclaration(for: dependency, in: dependencyGraph)
            }
        }
    }
    
    func resolvedDeclarationsBySource(for dependency: Dependency,
                                      in dependencyContainer: DependencyContainer) throws -> [(source: ConcreteType?, declaration: MetaDependencyDeclaration)] {
        
        let cacheIndex = InspectorCacheIndex(dependency, dependencyContainer)
        if let resolvedDeclarations = resolvedDeclarationsBySourceCache[cacheIndex] {
            return resolvedDeclarations
        }
        let resolvedDeclarations = try _resolvedDeclarationsBySource(for: dependency, in: dependencyContainer)
        resolvedDeclarationsBySourceCache[cacheIndex] = resolvedDeclarations
        return resolvedDeclarations
    }
    
    func _resolvedDeclarationsBySource(for dependency: Dependency,
                                       in dependencyContainer: DependencyContainer) throws -> [(source: ConcreteType?, declaration: MetaDependencyDeclaration)] {
        let declaration = try self.declaration(for: dependency)
        
        switch dependency.kind {
        case .reference:
            do {
                let registrations = try inspector.resolve(dependency, from: dependencyContainer, inspectionLevel: .permissive)
                
                let resolvedDeclarations: [(ConcreteType?, MetaDependencyDeclaration)] = try registrations.lazy.sorted { lhs, rhs in
                    lhs.key.description < rhs.key.description
                }.compactMap { source, registration in
                    let isRootDependencyContainer = dependencyContainer.sources.isEmpty
                    let sources = isRootDependencyContainer ? [dependencyContainer.type] : dependencyContainer.sources
                    guard sources.contains(source) else { return nil }
                    return (source, try self.declaration(for: registration))
                }
                
                let resolvedDeclarationsSet = Set(resolvedDeclarations.lazy.map { $0.1 })
                if resolvedDeclarationsSet.count > 1 {
                    return resolvedDeclarations
                } else if let resolvedDeclaration = resolvedDeclarationsSet.first {
                    return [(nil, resolvedDeclaration)]
                } else {
                    return []
                }
            } catch {
                return []
            }
            
        case .parameter,
             .registration:
            return [(nil, declaration)]
        }
    }

    func containsDeclarationBasedOnSource(in dependencyContainer: DependencyContainer) throws -> Bool {
        let inputDependencies = try self.inputReferences(of: dependencyContainer)
        return try inputDependencies.contains { dependency in
            try resolvedDeclarationsBySource(for: dependency, in: dependencyContainer).count > 1
        }
    }
    
    func containsAmbiguousDeclarations(in dependencyContainer: DependencyContainer) throws -> Bool {
        if let value = containsAmbiguousDeclarationsCache[ObjectIdentifier(dependencyContainer)] {
            return value
        }
        let value = try _containsAmbiguousDeclarations(in: dependencyContainer)
        containsAmbiguousDeclarationsCache[ObjectIdentifier(dependencyContainer)] = value
        return value
    }
    
    func _containsAmbiguousDeclarations(in dependencyContainer: DependencyContainer) throws -> Bool {
        return try dependencyContainer.dependencies.orderedValues.contains { dependency in
            let declaration = try self.declaration(for: dependency)
            return declaration.isDisambiguated
        }
    }
    
    func inputReferences(of dependencyContainer: DependencyContainer) throws -> [Dependency] {
        if let inputReferences = inputReferencesCache[ObjectIdentifier(dependencyContainer)] {
            return inputReferences
        }
        
        var visitedDependencyContainers = Set<ObjectIdentifier>()
        let inputReferences = try _inputReferences(of: dependencyContainer, &visitedDependencyContainers).sorted { lhs, rhs in
            try declaration(for: lhs).declarationName < declaration(for: rhs).declarationName
        }
        
        inputReferencesCache[ObjectIdentifier(dependencyContainer)] = inputReferences
        return inputReferences
    }

    func _inputReferences(of dependencyContainer: DependencyContainer,
                          _ visitedDependencyContainers: inout Set<ObjectIdentifier>) throws -> [Dependency] {
        
        guard visitedDependencyContainers.contains(ObjectIdentifier(dependencyContainer)) == false else { return [] }
        visitedDependencyContainers.insert(ObjectIdentifier(dependencyContainer))
        
        let directReferences = dependencyContainer.references
        let indirectReferences = try dependencyContainer.registrations.flatMap { registration -> [Dependency] in
            let target = try dependencyGraph.dependencyContainer(for: registration)
            return try _inputReferences(of: target, &visitedDependencyContainers)
        }
        
        let referencesByDeclaration = try (directReferences + indirectReferences)
            .reduce(into: OrderedDictionary<MetaDependencyDeclaration, Dependency>()) { references, reference in
                let declaration = try self.declaration(for: reference)
                references[declaration] = reference
            }
        
        let registrationDeclaration = Set(try dependencyContainer.registrations.lazy.map { try declaration(for: $0) })
        
        return referencesByDeclaration.orderedKeyValues.lazy
            .filter { registrationDeclaration.contains($0.key) == false }
            .map { $0.value }
    }
}
