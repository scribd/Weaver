//
//  Instance.swift
//  WeaverDI
//
//  Created by Théophane Rupin on 6/10/18.
//

import Foundation

extension Builder {
    
    /// Instantiation strategies enumeration.
    enum Instance {
        case transient(TransientInstance)
        case weakLazy(WeakLazyInstance)
        case strongLazy(StrongLazyInstance)
        
        init(scope: Scope, body: @escaping Body) {
            if scope.isTransient {
                self = .transient(.make(body))
            } else if scope.isWeak {
                self = .weakLazy(.make(body))
            } else {
                self = .strongLazy(.make(body))
            }
        }
        
        func getInstance(parameters: () -> P) -> I {
            switch self {
            case .transient(let instance):
                return instance.getInstance(parameters: parameters)
            case .weakLazy(let instance):
                return instance.getInstance(parameters: parameters)
            case .strongLazy(let instance):
                return instance.getInstance(parameters: parameters)
            }
        }
    }
}

// MARK: - TransientInstance

extension Builder {
    
    /// A `TransientInstance` is an instance type which only builds without storing any reference.
    final class TransientInstance {
        
        private let body: Body
        
        init(_ body: @escaping Body) {
            self.body = body
        }
        
        static func make(_ body: @escaping Body) -> TransientInstance {
            return TransientInstance(body)
        }

        func getInstance(parameters: () -> P) -> I {
            return body(parameters)
        }
    }
}

// MARK: - StrongLazyInstance

extension Builder {
    
    /// A `StrongLazyInstance` is a thread-safe instance type which lazily builds
    /// and stores a strong reference on the service.
    /// This version is optimized for any os lower than OSX 10.12 or iOS 10.0
    class StrongLazyInstance {
        
        fileprivate let body: Body
        
        fileprivate var instance: I?
        fileprivate var isLoaded = false

        private let instanceLocker = DispatchSemaphore(value: 1)
        private let isLoadedDispatchQueue = DispatchQueue(label: "\(Builder.self).isLoadedDispatchQueue", attributes: .concurrent)
        
        init(_ body: @escaping Body) {
            self.body = body
        }
        
        static func make(_ body: @escaping Body) -> StrongLazyInstance {
            if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                return StrongLazyInstance_OSX_10_12_iOS_10_0(body)
            } else {
                return StrongLazyInstance(body)
            }
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
    
    /// A `StrongLazyInstance_OSX_10_12_iOS_10_0` is a thread-safe instance type which lazily builds
    /// and stores a strong reference on the service.
    /// This version is optimized for any os greater than OSX 10.12 or iOS 10.0
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    final class StrongLazyInstance_OSX_10_12_iOS_10_0: StrongLazyInstance {
        
        private var lock = os_unfair_lock()
        
        override func getInstance(parameters: () -> P) -> I {
            
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
}

// MARK: - WeakLazyInstance

extension Builder {
    
    /// A `WeakLazyInstance` is a thread-safe instance type which lazily builds
    /// and stores a weak reference on the service.
    /// This version is optimized for any os lower than OSX 10.12 or iOS 10.0
    class WeakLazyInstance {
        
        fileprivate let body: Body
        
        fileprivate weak var instance: AnyObject?
        
        private let instanceLocker = DispatchSemaphore(value: 1)
        
        init(_ body: @escaping Body) {
            self.body = body
        }
        
        static func make(_ body: @escaping Body) -> WeakLazyInstance {
            if #available(OSX 10.12, *), #available(iOS 10.0, *) {
                return WeakLazyInstance_OSX_10_12_iOS_10_0(body)
            } else {
                return WeakLazyInstance(body)
            }
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
    /// A `WeakLazyInstance_OSX_10_12_iOS_10_0` is a thread-safe instance type which lazily builds
    /// and stores a weak reference on the service.
    /// This version is optimized for any os greater than OSX 10.12 or iOS 10.0
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    final class WeakLazyInstance_OSX_10_12_iOS_10_0: WeakLazyInstance {
        
        private var lock = os_unfair_lock()
        
        override func getInstance(parameters: () -> P) -> I {
            
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
}
