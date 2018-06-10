//
//  Builder.swift
//  WeaverDI
//
//  Created by Théophane Rupin on 6/7/18.
//

import Foundation

/// A representation of any builder.
protocol AnyBuilder {
    
    var scope: Scope { get }
}

// MARK: - Builder

/// A `Builder` is an object responsible for lazily building the instance of a service.
/// It is fully thread-safe.
/// - Parameters
///     - I: Instance type.
///     - P: Parameters type. Usually a tuple containing multiple parameters (eg. `(p1: Int, p2: String, ...)`)
final class Builder<I, P>: AnyBuilder {
    
    typealias Body = (() -> P) -> I
    
    let scope: Scope

    private var instance: Instance

    /// Inits a builder.
    /// - Parameters
    ///     - scope: Service's scope used to determine which building & storing strategy to use.
    ///     - body: Block responsible of calling the service's initializer (eg. `init(p1: Int, p2: String, ...)`).
    init(scope: Scope, body: @escaping Body) {
        self.scope = scope
        instance = Instance(scope: scope, body: body)
    }
    
    /// Makes the builder's body, which can then get called to build the service's instance, and store it.
    func make() -> Body {
        return { (parameters: () -> P) -> I in
            return self.instance.getInstance(parameters: parameters)
        }
    }
}
