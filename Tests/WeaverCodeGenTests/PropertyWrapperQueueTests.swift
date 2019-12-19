//
//  PropertyWrapperStackTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 12/19/19.
//

import Foundation
import XCTest

@testable import WeaverCodeGen

///
/// This test demonstrates how property wrappers are getting their associated dependency
/// from a scpecific dependency container instance rather than from a shared one.
///
/// The mechanism works with a shared FIFO queue of *dynamic resolvers*.
///
/// For this to work, a dependency always has to be built from its predecessor's
/// dependency container.
///
/// 1. First, the building dependency container puts a barrier to the queue with a recursive lock.
/// 2. Then, it pushes the necessary resolvers to the queue, **following their declaration exact order**.
/// 3. Finnally, it calls the dependency's initializer, which will immediately build the property wrappers
///    in their order of declaration. When a property wrapper is initialized, it immediately retrives the first
///    resolver in the queue and removes it.
///
/// As you can see this process relies on the way Swift internally initializes types in their
/// order of declaration. If this rule was to change in future versions of Swift, this test would detect it.
///
final class PropertyWrapperQueueTests: XCTestCase {
    
    func test_injectable_type_builds_without_memory_corruption() {
        let injectableType = MainDependencyContainer.makeInjectableType(42, "42", false)
        XCTAssertEqual(injectableType.intDependency, 42)
        XCTAssertEqual(injectableType.stringDependency, "42")
        XCTAssertEqual(injectableType.boolDependency, false)
    }
}

// MARK: - Client Code

private final class InjectableType {
    
    @Weaver(.reference)
    var intDependency: Int
    
    @Weaver(.reference)
    var stringDependency: String
    
    @Weaver(.reference)
    var boolDependency: Bool
}

// MARK: - Generated Code

private final class MainDependencyContainer {
    
    enum Scope {
        case transient
        case container
        case weak
        case lazy
    }

    enum DependencyKind {
        case registration
        case reference
        case parameter
    }
    
    static var onFatalError: (String, StaticString, UInt) -> Never = { message, file, line in
        Swift.fatalError(message, file: file, line: line)
    }

    fileprivate static func fatalError(file: StaticString = #file, line: UInt = #line) -> Never {
        onFatalError("Invalid memory graph. This is never suppose to happen. Please file a ticket at https://github.com/scribd/Weaver", file, line)
    }

    private static var _dynamicResolvers = [Any]()

    fileprivate static func _popDynamicResolver<Resolver>(_ resolverType: Resolver.Type) -> Resolver {
        guard let dynamicResolver = _dynamicResolvers.removeFirst() as? Resolver else {
            MainDependencyContainer.fatalError()
        }
        return dynamicResolver
    }

    static func _pushDynamicResolver<Resolver>(_ resolver: Resolver) {
        _dynamicResolvers.append(resolver)
    }
    
    static func makeInjectableType(_ intDependency: Int, _ stringDependency: String, _ boolDependency: Bool) -> InjectableType {
        MainDependencyContainer._dynamicResolvers.append({ intDependency })
        MainDependencyContainer._dynamicResolvers.append({ stringDependency })
        MainDependencyContainer._dynamicResolvers.append({ boolDependency })
        return InjectableType()
    }
}

@propertyWrapper
private struct Weaver<ConcreteType, AbstractType> {

    typealias Resolver = () -> AbstractType
    let resolver = MainDependencyContainer._popDynamicResolver(Resolver.self)

    init(_ kind: MainDependencyContainer.DependencyKind,
         type: ConcreteType.Type,
         scope: MainDependencyContainer.Scope = .container,
         setter: Bool = false,
         escaping: Bool = false,
         builder: Optional<Any> = nil) {
        // no-op
    }

    var wrappedValue: AbstractType {
        return resolver()
    }
}

private extension Weaver where ConcreteType == Void {
    init(_ kind: MainDependencyContainer.DependencyKind,
         scope: MainDependencyContainer.Scope = .container,
         setter: Bool = false,
         escaping: Bool = false,
         builder: Optional<Any> = nil) {
        // no-op
    }
}
