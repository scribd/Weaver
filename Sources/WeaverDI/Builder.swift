//
//  Builder.swift
//  WeaverDI
//
//  Created by Théophane Rupin on 6/7/18.
//

import Foundation

// MARK: - Any

protocol AnyBuilder {
    
    var scope: Scope { get }
}

// MARK: - Builder

final class Builder<I, P>: AnyBuilder {
    typealias Body = (() -> P) -> I

    private var lazyInstance: LazyInstance

    init(scope: Scope, body: @escaping Body) {
        lazyInstance = LazyInstance(scope: scope, body: body)
    }
    
    var scope: Scope {
        return lazyInstance.scope
    }
    
    func getLazyBuilder() -> Body {
        
        guard !lazyInstance.scope.isTransient else {
            return lazyInstance.body
        }
        
        return { (parameters: () -> P) -> I in
            return self.lazyInstance.getInstance(parameters: parameters)
        }
    }
}

// MARK: - LazyInstance

private extension Builder {

    final class LazyInstance {
        
        let body: Body
        let scope: Scope
        
        private var instance: Instance?
        private let instanceLocker = DispatchSemaphore(value: 1)
        
        private var isLoaded = false
        private let isLoadedDispatchQueue = DispatchQueue(label: "\(Builder.self)", attributes: .concurrent)
        
        init(scope: Scope, body: @escaping Body) {
            self.scope = scope
            self.body = body
        }
        
        private var syncIsSet: Bool {
            set {
                isLoadedDispatchQueue.async(flags: .barrier) {
                    self.isLoaded = newValue
                }
            }
            get {
                var isLoaded = false
                isLoadedDispatchQueue.sync {
                    isLoaded = self.isLoaded
                }
                return isLoaded
            }
        }
        
        func getInstance(parameters: () -> P) -> I {
            
            if syncIsSet {
                guard let instance = self.instance?.value else {
                    fatalError("Instance is nil, you just found a race condition.")
                }
                return instance
            }
            
            instanceLocker.wait()
            
            if syncIsSet {
                guard let instance = self.instance?.value else {
                    fatalError("Instance is nil, you just found a race condition.")
                }
                instanceLocker.signal()
                return instance
            }
            
            let instance = body(parameters)
            self.instance = Instance(value: instance, scope: self.scope)
            
            syncIsSet = true
            instanceLocker.signal()
            
            return instance
        }
    }

    // MARK: - Instance

    private final class Instance {
        
        private weak var weakValue: AnyObject?

        private var strongValue: I?
        
        init(value: I, scope: Scope) {
            
            if scope.isWeak {
                weakValue = value as AnyObject
            } else {
                strongValue = value
            }
        }
        
        var value: I? {
            if let value = weakValue as? I {
                return value
            }
            return strongValue
        }
    }
}
