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
    
    private let body: Body
    
    let scope: Scope

    private var lazyInstance: LazyInstance

    init(scope: Scope, body: @escaping Body) {

        self.scope = scope
        self.body = body
        
        if scope.isWeak {
            lazyInstance = .weak(WeakLazyInstance(body: body))
        } else {
            lazyInstance = .strong(StrongLazyInstance(body: body))
        }
    }
    
    func getLazyBuilder() -> Body {
        
        guard !scope.isTransient else {
            return body
        }
        
        return { (parameters: () -> P) -> I in
            return self.lazyInstance.getInstance(parameters: parameters)
        }
    }
}

// MARK: - LazyInstance

private extension Builder {

    private enum LazyInstance {
        case strong(StrongLazyInstance)
        case weak(WeakLazyInstance)
        
        func getInstance(parameters: () -> P) -> I {
            switch self {
            case .strong(let lazyInstance):
                return lazyInstance.getInstance(parameters: parameters)
            case .weak(let lazyInstance):
                return lazyInstance.getInstance(parameters: parameters)
            }
        }
    }
}

// MARK: - LazyInstance

private extension Builder {

    final class StrongLazyInstance {
        
        private let body: Body
        
        private var instance: I?
        private let instanceLocker = DispatchSemaphore(value: 1)
        
        private var isLoaded = false
        private let isLoadedDispatchQueue = DispatchQueue(label: "\(Builder.self).isLoadedDispatchQueue", attributes: .concurrent)
        
        init(body: @escaping Body) {
            self.body = body
        }
        
        private var syncIsLoaded: Bool {
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
            
            if syncIsLoaded {
                guard let instance = self.instance else {
                    fatalError("Instance is nil, you just found a race condition.")
                }
                return instance
            }
            
            instanceLocker.wait()
            
            if syncIsLoaded {
                guard let instance = self.instance else {
                    fatalError("Instance is nil, you just found a race condition.")
                }
                instanceLocker.signal()
                return instance
            }
            
            let instance = body(parameters)
            self.instance = instance
            
            syncIsLoaded = true
            instanceLocker.signal()
            
            return instance
        }
    }
}

// MARK: - WeakLazyInstance

private extension Builder {
    
    final class WeakLazyInstance {
        
        private let body: Body
        
        private weak var instance: AnyObject?
        private let instanceLocker = DispatchSemaphore(value: 1)
        
        init(body: @escaping Body) {
            self.body = body
        }
        
        func getInstance(parameters: () -> P) -> I {
            self.instanceLocker.wait()
            defer { self.instanceLocker.signal() }
            
            if let instance = self.instance as? I {
                return instance
            }
            
            let instance = body(parameters)
            self.instance = instance as AnyObject
            
            return instance
        }
    }
}
