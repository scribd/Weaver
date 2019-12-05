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
    
    public init(dependencyGraph: DependencyGraph,
                inspector: Inspector,
                version: String,
                testableImports: [String]?) throws {

        self.dependencyGraph = dependencyGraph
        self.inspector = inspector
        self.version = version
        self.testableImports = testableImports
    }
    
    private var _file: MetaWeaverFile?
    private func file() throws -> MetaWeaverFile {
        if let file = _file {
            return file
        }
        let file = try MetaWeaverFile(dependencyGraph, inspector, version, testableImports)
        _file = file
        return file
    }
    
    public func generate() throws -> String? {
        return try file().meta().swiftString
    }
    
    public func generateTests() throws -> String? {
        return try file().metaTests().swiftString
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
    
    let parameters: [Dependency]
    
    private let includeTypeInName: Bool
    
    private let includeParametersInName: Bool
    
    init(for dependency: Dependency,
         in dependencyGraph: DependencyGraph,
         includeTypeInName: Bool = false,
         includeParametersInName: Bool = false) throws {
        
        name = dependency.dependencyName
        type = dependency.type
        self.includeTypeInName = includeTypeInName
        self.includeParametersInName = includeParametersInName
        
        switch dependency.kind {
        case .registration,
             .reference:
            let dependencyContainer = try dependencyGraph.dependencyContainer(for: dependency)
            parameters = dependencyContainer.parameters
        case .parameter:
            parameters = []
        }
    }
    
    private lazy var desambiguationHash: String? = {
        var desambiguationString = String()
        if includeParametersInName {
            desambiguationString += parameters.map { parameter in
                parameter.dependencyName + parameter.type.types.sorted.map { $0.toTypeName }.joined()
            }.joined()
        }
        if includeTypeInName {
            desambiguationString += type.types.sorted.map { $0.toTypeName }.joined()
        }
        guard desambiguationString.isEmpty == false else {
            return nil
        }
        return sha(desambiguationString)
    }()
    
    lazy var declarationName = "\(name)\(desambiguationHash.flatMap { "_\($0)" } ?? String())"
    lazy var resolverTypeName = "\(name.typeCase)\(desambiguationHash.flatMap { "_\($0)_" } ?? String())Resolver"
    lazy var setterName = "set\(name.typeCase)\(desambiguationHash.flatMap { "_\($0)" } ?? String())"
    lazy var setterTypeName = "\(name.typeCase)\(desambiguationHash.flatMap { "_\($0)_" } ?? String())Setter"
    lazy var declarationDoubleName = "\(name)\(desambiguationHash.flatMap { "_\($0)_" } ?? String())Double"
    
    lazy var isDesambiguated = desambiguationHash != nil
    
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
        guard lhs.desambiguationHash == rhs.desambiguationHash else { return false }
        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(desambiguationHash)
    }
}

// MARK: - Weaver File

private final class MetaWeaverFile {
    
    private let dependencyGraph: DependencyGraph
    
    private let inspector: Inspector
    
    private let version: String
    
    private let testableImports: [String]?

    // Pre computed data
    
    private let declarations: Set<MetaDependencyDeclaration>
    private let orderedDeclarations: [MetaDependencyDeclaration]

    private var setterDeclarations = [MetaDependencyDeclaration]()
    private var doesSupportObjcByDeclaration = [MetaDependencyDeclaration: Bool]()
    private var isParameterByDeclaration = [MetaDependencyDeclaration: Bool]()
    
    private lazy var doesSupportObjc = dependencyGraph.dependencies.contains { $0.configuration.doesSupportObjc }

    // Cached data
    
    private var inputReferencesCache = [ObjectIdentifier: [Dependency]]()
    private var resolvedDeclarationsBySourceCache = [InspectorCacheIndex: [(source: ConcreteType?, declaration: MetaDependencyDeclaration)]]()
    private var containsAmbiguousDeclarationsCache = [ObjectIdentifier: Bool]()
    
    init(_ dependencyGraph: DependencyGraph,
         _ inspector: Inspector,
         _ version: String,
         _ testableImports: [String]?) throws {
        
        self.dependencyGraph = dependencyGraph
        self.inspector = inspector
        self.version = version
        self.testableImports = testableImports
        
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
        }
    }
    
    static func header(_ version: String) -> [Comment] {
        return [
            .documentation("This file is generated by Weaver \(version)"),
            .documentation("DO NOT EDIT!")
        ]
    }
    
    // MARK: - Main File

    func meta() throws -> Meta.File {
        return File(name: "Weaver.swift")
            .adding(members: MetaWeaverFile.header(version))
            .adding(imports: dependencyGraph.imports.sorted().map { Import(name: $0) })
            .adding(members: try body())
    }
    
    private func body() throws -> [FileBodyMember] {
        return try [
            [
                EmptyLine(),
                mainDependencyContainer(),
                EmptyLine()
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
            dependencyResolverProxies()
        ].flatMap { $0 }
    }
    
    // MARK: - Tests File

    func metaTests() -> Meta.File {
        let imports = dependencyGraph.imports.subtracting(testableImports ?? [])
        return File(name: "WeaverTest.swift")
            .adding(members: MetaWeaverFile.header(version))
            .adding(imports: imports.sorted().map { Import(name: $0) })
            .adding(imports: testableImports?.sorted().map { Import(name: $0, testable: true) } ?? [])
            .adding(members: bodyTests())
    }
    
    private func bodyTests() -> [FileBodyMember] {
        return [
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
        return Type(identifier: .mainDependencyContainerTypeID)
            .with(objc: doesSupportObjc)
            .adding(inheritedType: doesSupportObjc ? .nsObject : nil)
            .adding(member: PlainCode(code: """
            
            static var onFatalError: (String, StaticString, UInt) -> Never = { message, file, line in
                Swift.fatalError(message, file: file, line: line)
            }
                
            private static func fatalError(file: StaticString = #file, line: UInt = #line) -> Never {
                onFatalError("Invalid memory graph. This is never suppose to happen. Please file a ticket at https://github.com/scribd/Weaver", file, line)
            }

            private typealias ParametersCopier = (MainDependencyContainer) -> Void
            private typealias Builder<T> = (ParametersCopier?) -> T

            private func builder<T>(_ value: T) -> Builder<T> {
                return { [weak self] copyParameters in
                    guard let self = self else {
                        MainDependencyContainer.fatalError()
                    }
                    copyParameters?(self)
                    return value
                }
            }

            private func weakBuilder<T>(_ value: T) -> Builder<T> where T: AnyObject {
                return { [weak self, weak value] copyParameters in
                    guard let self = self, let value = value else {
                        MainDependencyContainer.fatalError()
                    }
                    copyParameters?(self)
                    return value
                }
            }

            private func lazyBuilder<T>(_ builder: @escaping Builder<T>) -> Builder<T> {
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

            private func weakLazyBuilder<T>(_ builder: @escaping Builder<T>) -> Builder<T> where T: AnyObject {
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

            private static func fatalBuilder<T>() -> Builder<T> {
                return { _ in
                    MainDependencyContainer.fatalError()
                }
            }
            """))
            .adding(members: try resolversImplementation())
            .adding(members: settersImplementation())
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                .with(override: doesSupportObjc)
                .with(accessLevel: .private)
            )
            .adding(members: try dependencyResolverCopyMethods())
    }
    
    func resolversImplementation() throws -> [TypeBodyMember] {
        return try orderedDeclarations.flatMap { declaration -> [TypeBodyMember] in
            var members: [TypeBodyMember] = [
                EmptyLine(),
                Property(variable: Variable(name: "_\(declaration.declarationName)")
                    .with(type: .builder(of: declaration.type.typeID))
                    .with(immutable: false))
                    .with(accessLevel: .private)
                    .with(value: TypeIdentifier.mainDependencyContainerTypeID.reference + .named("fatalBuilder") | .call()),
            ]
            
            if declaration.parameters.isEmpty {
                members += [
                    ComputedProperty(variable: Variable(name: declaration.declarationName)
                        .with(type: declaration.type.typeID))
                        .adding(member: Return(value: .named("_\(declaration.declarationName)") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.nil))
                        )))
                ]
            } else {
                let _selfVariable = Variable(name: "_self")
                members += [
                    Function(kind: .named(declaration.declarationName))
                        .with(resultType: declaration.type.typeID)
                        .adding(parameters: declaration.parameters.compactMap { parameter in
                            guard let concreteType = parameter.type.concreteType else { return nil }
                            return FunctionParameter(name: parameter.dependencyName, type: concreteType.typeID)
                        })
                        .adding(member: Return(value: .named("_\(declaration.declarationName)") | .block(FunctionBody()
                            .adding(parameter: FunctionBodyParameter(name: _selfVariable.name))
                            .adding(members: try declaration.parameters.compactMap { parameter in
                                let declaration = try self.declaration(for: parameter)
                                return Assignment(
                                    variable: _selfVariable.reference + .named("_\(declaration.declarationName)"),
                                    value: _selfVariable.reference + .named("builder") | .call(Tuple()
                                        .adding(parameter: TupleParameter(value:  Reference.named(parameter.dependencyName)))
                                    )
                                )
                            })
                        )))
                ]
            }
            
            return members
        }
    }

    func resolvers() -> [FileBodyMember] {
        return orderedDeclarations.flatMap { declaration -> [FileBodyMember] in
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
                            .adding(parameters: declaration.parameters.compactMap { parameter in
                                guard let concreteType = parameter.type.concreteType else { return nil }
                                return FunctionParameter(name: parameter.dependencyName, type: concreteType.typeID)
                            })
                    )
            ]
        }
    }
    
    func resolversImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyContainerTypeID)
            .adding(inheritedTypes: orderedDeclarations.map { declaration in
                TypeIdentifier(name: declaration.resolverTypeName)
            })
    }
    
    func settersImplementation() -> [TypeBodyMember] {
        return setterDeclarations.flatMap { declaration -> [TypeBodyMember] in
            [
                EmptyLine(),
                Function(kind: .named(declaration.setterName))
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: declaration.type.typeID))
                    .adding(member: Assignment(
                        variable: Reference.named("_\(declaration.declarationName)"),
                        value: Reference.named("builder") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("value")))
                        )
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
        return Extension(type: .mainDependencyContainerTypeID)
            .adding(inheritedTypes: setterDeclarations.map { declaration in
                TypeIdentifier(name: declaration.setterTypeName)
            })
    }
    
    func dependencyResolvers() throws -> [FileBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [FileBodyMember] in
            switch dependencyContainer.declarationSource {
            case .type:
                let resolverTypeIDs = try dependencyContainer.dependencies.orderedValues.map { dependency in
                    TypeIdentifier(name: try declaration(for: dependency).resolverTypeName)
                }
                let setterTypeIDs = try dependencyContainer.registrations.compactMap { registration -> TypeIdentifier? in
                    guard registration.configuration.setter else { return nil }
                    return TypeIdentifier(name: try declaration(for: registration).setterTypeName)
                }
                guard let andTypeIDs = TypeIdentifier.and(resolverTypeIDs + setterTypeIDs) else { return [] }
                return [
                    EmptyLine(),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: dependencyContainer.type.dependencyResolverTypeID.name),
                        value: andTypeIDs
                    )
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
            return [
                EmptyLine(),
                TypeAlias(
                    identifier: TypeAliasIdentifier(name: target.type.inputDependencyResolverTypeID.name),
                    value: TypeIdentifier.and(declarations.map { declaration in
                        TypeIdentifier(name: declaration.resolverTypeName)
                    })!
                )
            ]
        }
    }
    
    func dependencyResolverCopyMethods() throws -> [TypeBodyMember] {
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [TypeBodyMember] in
            guard dependencyContainer.declarationSource == .type else { return [] }
            
            let _selfVariable = Variable(name: "_self")
            let sourceVariable = Variable(name: "source")

            let inputReferences = try self.inputReferences(of: dependencyContainer)
            let containsAmbiguousDeclarations = try self.containsAmbiguousDeclarations(in: dependencyContainer)
            let containsDeclarationBasedOnSource = try self.containsDeclarationBasedOnSource(in: dependencyContainer)

            let selfReferenceDeclarations = try dependencyContainer.references.reduce(into: Set<MetaDependencyDeclaration>()) { declarations, reference in
                guard try dependencyGraph.isSelfReference(reference) else { return }
                let declaration = try self.declaration(for: reference)
                declarations.insert(declaration)
            }
            
            var members: [TypeBodyMember] = [
                EmptyLine(),
                Function(kind: .named(dependencyContainer.type.dependencyResolverVariable.name))
                    .with(resultType: containsAmbiguousDeclarations ?
                        dependencyContainer.type.dependencyResolverProxyTypeID : dependencyContainer.type.dependencyResolverTypeID
                    )
                    .adding(parameter: containsDeclarationBasedOnSource ?
                        FunctionParameter(alias: "_", name: sourceVariable.name, type: .string) : nil
                    )
                    .adding(member: Assignment(variable: _selfVariable, value: TypeIdentifier.mainDependencyContainerTypeID.reference | .call()))
                    .adding(members: try inputReferences.compactMap { reference in
                        
                        let declaration = try self.declaration(for: reference)
                        guard selfReferenceDeclarations.contains(declaration) == false else {
                            return nil
                        }
                        
                        let assignment: (MetaDependencyDeclaration) -> Assignment = { resolvedDeclaration in
                            Assignment(
                                variable: _selfVariable.reference + .named("_\(declaration.declarationName)"),
                                value: _selfVariable.reference + .named("builder") | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Reference.named(resolvedDeclaration.declarationName)))
                                )
                            )
                        }
                        
                        let resolvedDeclarations = try resolvedDeclarationsBySource(for: reference, in: dependencyContainer)
                        if resolvedDeclarations.count > 1 {
                            return Switch(reference: sourceVariable.reference)
                                .adding(cases: resolvedDeclarations.compactMap { source, declaration in
                                    guard let source = source else { return nil }
                                    return SwitchCase()
                                        .adding(value: Value.string(source.description))
                                        .adding(member: assignment(declaration))
                                })
                                .adding(case: SwitchCase(name: .default)
                                    .adding(member: TypeIdentifier.mainDependencyContainerTypeID.reference + .named("fatalError") | .call())
                                )
                        } else if let resolvedDeclaration = resolvedDeclarations.first?.declaration {
                            return assignment(resolvedDeclaration)
                        } else {
                            return nil
                        }
                    })
                    .adding(members: try dependencyContainer.registrations.compactMap { registration in
                        try copyAssignment(for: registration, from: dependencyContainer)
                    })
                    .adding(members: try dependencyContainer.registrations.compactMap { registration in
                        guard registration.configuration.setter == false else { return nil }
                        switch registration.configuration.scope {
                        case .container,
                             .weak:
                            let declaration = try self.declaration(for: registration)
                            return Assignment(
                                variable: Reference.named("_"),
                                value: _selfVariable.reference + .named("_\(declaration.declarationName)") | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Value.nil))
                                )
                            )
                        case .lazy,
                             .transient:
                            return nil
                        }
                    })
                    .adding(member: Return(value: containsAmbiguousDeclarations ?
                        dependencyContainer.type.dependencyResolverProxyTypeID.reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: _selfVariable.reference))
                        ) :
                        _selfVariable.reference)
                    )
            ]
            
            if dependencyContainer.references.isEmpty {
                members += [
                    EmptyLine(),
                    Function(kind: .named(dependencyContainer.type.dependencyResolverVariable.name))
                        .with(resultType: containsAmbiguousDeclarations ?
                            dependencyContainer.type.dependencyResolverProxyTypeID : dependencyContainer.type.dependencyResolverTypeID
                        )
                        .with(static: true)
                        .adding(member: Return(value:
                            TypeIdentifier.mainDependencyContainerTypeID.reference | .call() + dependencyContainer.type.dependencyResolverVariable.reference | .call()
                        ))
                ]
            }
            
            return members
        }
    }
    
    func copyAssignment(for registration: Dependency,
                        from dependencyContainer: DependencyContainer) throws -> Assignment? {
        
        guard registration.configuration.setter == false else { return nil }

        let _selfVariable = Variable(name: "_self")
        let __selfVariable = Variable(name: "__self")
        let __mainSelfVariable = Variable(name: "__mainSelf")
        let valueVariable = Variable(name: "value")

        guard let concreteType = registration.type.concreteType else { return nil }
        let declaration = try self.declaration(for: registration)
        
        let target = try dependencyGraph.dependencyContainer(for: registration)
        let targetContainsDeclarationBasedOnSource = try containsDeclarationBasedOnSource(in: target)
        let targetContainsAmbiguousDeclarations = try containsAmbiguousDeclarations(in: target)
        let targetSelfReferences = try target.references.filter { reference in
            try dependencyGraph.isSelfReference(reference)
        }
        
        let hasInputDependencies =
            target.dependencies.isEmpty == false ||
            registration.configuration.customBuilder != nil ||
            declaration.parameters.isEmpty == false

        let hasParameters = declaration.parameters.isEmpty == false
        let containsAmbiguousDeclarations = try self.containsAmbiguousDeclarations(in: dependencyContainer)

        let resolverReference: Reference?
        let shouldUnwrapResolverReference: Bool
        var builderReference: Reference
        if let customBuilder = registration.configuration.customBuilder {
            switch target.declarationSource {
            case .type:
                resolverReference = hasInputDependencies ? _selfVariable.reference + concreteType.dependencyResolverVariable.reference | .call(Tuple()
                    .adding(parameter: targetContainsDeclarationBasedOnSource ? TupleParameter(value: Value.string(dependencyContainer.type.description)) : nil)
                ) : nil
                builderReference = .named(customBuilder) | .call(Tuple()
                    .adding(parameter: hasInputDependencies ? TupleParameter(value: __selfVariable.reference) : nil)
                )
                shouldUnwrapResolverReference = false
            case .reference,
                 .registration:
                resolverReference = containsAmbiguousDeclarations ? dependencyContainer.type.dependencyResolverProxyTypeID.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: _selfVariable.reference))
                ) : nil
                builderReference = .named(customBuilder) | .call(Tuple()
                    .adding(parameter: TupleParameter(value:
                        (containsAmbiguousDeclarations ? __selfVariable : _selfVariable).reference |
                        (containsAmbiguousDeclarations ? +_selfVariable.reference : .none) |
                        .as |
                        target.type.inputDependencyResolverTypeID.reference
                    ))
                )
                shouldUnwrapResolverReference = containsAmbiguousDeclarations
            }
        } else {
            resolverReference = hasInputDependencies ? _selfVariable.reference + concreteType.dependencyResolverVariable.reference | .call(Tuple()
                .adding(parameter: targetContainsDeclarationBasedOnSource ? TupleParameter(value: Value.string(dependencyContainer.type.description)) : nil)
            ) : nil
            builderReference = concreteType.typeID.reference | .call(Tuple()
                .adding(parameter: hasInputDependencies ? TupleParameter(
                    name: "injecting",
                    value: __selfVariable.reference
                ) : nil)
            )
            shouldUnwrapResolverReference = targetContainsAmbiguousDeclarations
        }
        
        let builderFunction: Reference
        switch registration.configuration.scope {
        case .container,
             .lazy:
            builderFunction = .named("lazyBuilder")
        case .weak:
            builderFunction = .named("weakLazyBuilder")
        case .transient:
            builderFunction = .none
        }
        
        builderReference = builderFunction | .block(FunctionBody()
            .adding(parameter: FunctionBodyParameter(name: hasParameters ? "copyParameters" : "_"))
            .adding(context: hasInputDependencies ? FunctionBodyContext(name: _selfVariable.name, kind: .weak) : nil)
            .adding(member: hasInputDependencies ?
                Guard(assignment: Assignment(variable: _selfVariable, value: _selfVariable.reference))
                    .adding(member: TypeIdentifier.mainDependencyContainerTypeID.reference + .named("fatalError") | .call()) : nil)
            .adding(member: resolverReference.flatMap {
                Assignment(variable: __selfVariable, value: $0)
            })
            .adding(member: hasParameters ? .named("copyParameters") | .unwrap | .call(Tuple()
                .adding(parameter: TupleParameter(
                    value: (resolverReference != nil ? __selfVariable : _selfVariable).reference |
                        (shouldUnwrapResolverReference ? +_selfVariable.reference : .none) |
                        .named(" as! ") |
                        TypeIdentifier.mainDependencyContainerTypeID.reference
                ))
            ) : nil)
            .adding(members: targetSelfReferences.isEmpty == false ? try [
                Assignment(
                    variable: __mainSelfVariable,
                    value: (resolverReference != nil ? __selfVariable : _selfVariable).reference |
                        (shouldUnwrapResolverReference ? +_selfVariable.reference : .none) |
                        .named(" as! ") |
                        TypeIdentifier.mainDependencyContainerTypeID.reference
                ),
                Assignment(
                    variable: valueVariable,
                    value: builderReference
                )
            ] + targetSelfReferences.map { selfReference in
                let declaration = try self.declaration(for: selfReference)
                return Assignment(
                    variable: __mainSelfVariable.reference + .named("_\(declaration.declarationName)"),
                    value: __mainSelfVariable.reference + .named("weakBuilder") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: valueVariable.reference))
                    )
                )
            } + [
                Return(value: valueVariable.reference)
            ] : [
                Return(value: builderReference)
            ])
        )
        
        return Assignment(
            variable: _selfVariable.reference + .named("_\(declaration.declarationName)"),
            value: builderReference
        )
    }
    
    func dependencyResolverProxies() throws -> [FileBodyMember] {
        
        let _selfVariable = Variable(name: "_self")
        
        return try dependencyGraph.dependencyContainers.orderedValues.flatMap { dependencyContainer -> [FileBodyMember] in
            guard try containsAmbiguousDeclarations(in: dependencyContainer) else { return [] }
            
            return [
                EmptyLine(),
                Type(identifier: dependencyContainer.type.dependencyResolverProxyTypeID)
                    .with(kind: .struct)
                    .adding(member: EmptyLine())
                    .adding(member: Property(variable: _selfVariable
                        .with(type: dependencyContainer.type.dependencyResolverTypeID))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                        .adding(parameter: FunctionParameter(alias: "_", name: _selfVariable.name, type: dependencyContainer.type.dependencyResolverTypeID))
                        .adding(member: Assignment(variable: .named(.`self`) + _selfVariable.reference, value: _selfVariable.reference))
                    )
                    .adding(members: try dependencyContainer.dependencies.orderedValues.flatMap { dependency -> [TypeBodyMember] in
                        let declaration = try self.declaration(for: dependency)

                        var members: [TypeBodyMember] = [EmptyLine()]
                        if declaration.parameters.isEmpty {
                            members += [
                                ComputedProperty(variable: Variable(name: declaration.name)
                                    .with(type: declaration.type.typeID))
                                    .adding(member: Return(value: _selfVariable.reference + .named(declaration.declarationName)))
                            ]
                        } else {
                            members += [
                                Function(kind: .named(declaration.name))
                                    .with(resultType: declaration.type.typeID)
                                    .adding(parameters: declaration.parameters.compactMap { parameter in
                                        guard let concreteType = parameter.type.concreteType else { return nil }
                                        return FunctionParameter(name: parameter.dependencyName, type: concreteType.typeID)
                                    })
                                    .adding(member: Return(value: _selfVariable.reference + .named(declaration.declarationName) | .call(Tuple()
                                        .adding(parameters: declaration.parameters.map { parameter in
                                            return TupleParameter(name: parameter.dependencyName, value: Reference.named(parameter.dependencyName))
                                        })
                                    )))
                            ]
                        }
                        
                        return members
                    })
            ]
        }
    }
}

// MARK: - MainDependencyResolverStub

private extension MetaWeaverFile {
    
    func mainDependencyResolverStub() -> Type {
        return Type(identifier: .mainDependencyResolverStubTypeID)
            .with(kind: .class(final: false))
            .with(objc: doesSupportObjc)
            .adding(inheritedType: doesSupportObjc ? .nsObject : nil)
            .adding(members: resolversStubImplementation())
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`(convenience: false, optional: false))
                .with(override: doesSupportObjc)
            )
            .adding(members: settersStubImplementation())
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
                    var \(doubleVariable.name): \(concreteType.typeID.swiftString)\(concreteType.isOptional ? " = nil" : "!")
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
                            .adding(parameters: declaration.parameters.compactMap { parameter in
                                guard let concreteType = parameter.type.concreteType else { return nil }
                                return FunctionParameter(name: parameter.dependencyName, type: concreteType.typeID)
                            })
                            .adding(member: Return(value: doubleVariable.reference))
                    ]
                }
                
                return members
            }
        }
    }
    
    func resolversStubImplementationExtension() -> Extension {
        return Extension(type: .mainDependencyResolverStubTypeID)
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
        return Extension(type: .mainDependencyResolverStubTypeID)
            .adding(inheritedTypes: setterDeclarations.map { declaration in
                TypeIdentifier(name: declaration.setterTypeName)
            })
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
    
    func declaration(for dependency: Dependency) throws -> MetaDependencyDeclaration {
        let declaration = try MetaDependencyDeclaration(for: dependency, in: dependencyGraph, includeTypeInName: true, includeParametersInName: true)
        if declarations.contains(declaration) {
            return declaration
        } else {
            let declaration = try MetaDependencyDeclaration(for: dependency, in: dependencyGraph, includeTypeInName: true)
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
            guard dependencyContainer.sources.isEmpty == false else { return [] }
            
            do {
                let registrations = try inspector.resolve(dependency, from: dependencyContainer)
                
                let resolvedDeclarations: [(ConcreteType?, MetaDependencyDeclaration)] = try registrations.lazy.sorted { lhs, rhs in
                    lhs.key.description < rhs.key.description
                }.compactMap { source, registration in
                    guard dependencyContainer.sources.contains(source) else { return nil }
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
            return declaration.isDesambiguated
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
