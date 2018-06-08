//
//  Builder.swift
//  WeaverDI
//
//  Created by Théophane Rupin on 6/7/18.
//

import Foundation

// MARK: - Builder

final class Builder {
    
    let scope: Scope
    private let body: Any
    
    private var instance: Instance?
    private let instanceLocker = NSLock()
    
    private var isSet = false
    private let isSetDispatchQueue = DispatchQueue(label: "\(Builder.self)", attributes: .concurrent)
    
    init(scope: Scope, body: Any) {
        self.scope = scope
        self.body = body
    }
    
    private var syncIsSet: Bool {
        set {
            isSetDispatchQueue.async(flags: .barrier) {
                self.isSet = newValue
            }
        }
        get {
            var isSet = false
            isSetDispatchQueue.sync {
                isSet = self.isSet
            }
            return isSet
        }
    }
    
    func functor<P, I>() -> (() -> P) -> I {
        
        guard let body = body as? (() -> P) -> I else {
            fatalError("Type \(((() -> P) -> I).self) doesn't correspond to body type: \(self.body.self)")
        }
        
        guard !scope.isTransient else {
            return body
        }
        
        return { (parameters: () -> P) -> I in

            if self.syncIsSet {
                guard let instance = self.instance?.value as? I else {
                    fatalError()
                }
                return instance
            }

            self.instanceLocker.lock()
            
            if self.syncIsSet {
                guard let instance = self.instance?.value as? I else {
                    fatalError()
                }
                self.instanceLocker.unlock()
                return instance
            }

            let instance = body(parameters)
            self.instance = Instance(value: instance as AnyObject, scope: self.scope)
            
            self.syncIsSet = true

            self.instanceLocker.unlock()

            return instance
        }
    }
}

// MARK: - Instance

private final class Instance {
    private weak var weakValue: AnyObject?
    private var strongValue: AnyObject?
    
    init(value: AnyObject, scope: Scope) {
        
        if scope.isWeak {
            weakValue = value
        } else {
            strongValue = value
        }
    }
    
    var value: AnyObject? {
        return weakValue ?? strongValue ?? nil
    }
}
