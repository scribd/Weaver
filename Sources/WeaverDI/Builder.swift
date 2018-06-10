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
    
    let scope: Scope

    private var instance: Instance

    init(scope: Scope, body: @escaping Body) {

        self.scope = scope
        
        instance = Instance(scope: scope, body: body)
    }
    
    func make() -> Body {
        return { (parameters: () -> P) -> I in
            return self.instance.getInstance(parameters: parameters)
        }
    }
}

// MARK: - Instance

private extension Builder {

    private enum Instance {
        case transient(TransientInstance)
        case weakLazy(AnyWeakLazyInstance)
        case strongLazy(AnyStrongLazyInstance)

        init(scope: Scope, body: @escaping Body) {
            if scope.isTransient {
                self = .transient(TransientInstance(body: body))
            } else if scope.isWeak {
                if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                    self = .weakLazy(WeakLazyInstance_OSX_10_12_iOS_10_0(body: body))
                } else {
                    self = .weakLazy(WeakLazyInstance(body: body))
                }
            } else {
                if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                    self = .strongLazy(StrongLazyInstance_OSX_10_12_iOS_10_0(body: body))
                } else {
                    self = .strongLazy(StrongLazyInstance(body: body))
                }
            }
        }
        
        func getInstance(parameters: () -> P) -> I {
            switch self {
            case .transient(let instance):
                return instance.getInstance(parameters: parameters)

            case .weakLazy(let _instance):
                if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                    guard let instance = _instance as? WeakLazyInstance_OSX_10_12_iOS_10_0 else {
                        fatalError("Instance (\(_instance) is not of type \(WeakLazyInstance_OSX_10_12_iOS_10_0.self).")
                    }
                    return instance.getInstance(parameters: parameters)
                } else {
                    guard let instance = _instance as? WeakLazyInstance else {
                        fatalError("Instance (\(_instance) is not of type \(WeakLazyInstance.self).")
                    }
                    return instance.getInstance(parameters: parameters)
                }
                
            case .strongLazy(let _instance):
                if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                    guard let instance = _instance as? StrongLazyInstance_OSX_10_12_iOS_10_0 else {
                        fatalError("Instance (\(_instance) is not of type \(StrongLazyInstance_OSX_10_12_iOS_10_0.self).")
                    }
                    return instance.getInstance(parameters: parameters)
                } else {
                    guard let instance = _instance as? StrongLazyInstance else {
                        fatalError("Instance (\(_instance) is not of type \(StrongLazyInstance.self).")
                    }
                    return instance.getInstance(parameters: parameters)
                }
            }
        }
    }
}

// MARK: - TransientInstance

private extension Builder {

    final class TransientInstance {
     
        private let body: Body

        init(body: @escaping Body) {
            self.body = body
        }

        func getInstance(parameters: () -> P) -> I {
            return body(parameters)
        }
    }
}

// MARK: - StrongLazyInstance

private protocol AnyStrongLazyInstance {}

private extension Builder {

    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    final class StrongLazyInstance_OSX_10_12_iOS_10_0: AnyStrongLazyInstance {

        private let body: Body
        private var lock = os_unfair_lock()
        
        private var instance: I?
        
        init(body: @escaping Body) {
            self.body = body
        }
        
        func getInstance(parameters: () -> P) -> I {

            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            
            if let instance = self.instance {
                return instance
            }
            
            let instance = body(parameters)
            self.instance = instance
            
            return instance
        }
    }
    
    final class StrongLazyInstance: AnyStrongLazyInstance {
        
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

private protocol AnyWeakLazyInstance {}

private extension Builder {
    
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    final class WeakLazyInstance_OSX_10_12_iOS_10_0: AnyWeakLazyInstance {
        
        private let body: Body
        private var lock = os_unfair_lock()
        
        private weak var instance: AnyObject?
        
        init(body: @escaping Body) {
            self.body = body
        }
        
        func getInstance(parameters: () -> P) -> I {
            
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            
            if let instance = self.instance as? I {
                return instance
            }
            
            let instance = body(parameters)
            self.instance = instance as AnyObject
            
            return instance
        }
    }
    
    final class WeakLazyInstance: AnyWeakLazyInstance {
        
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
