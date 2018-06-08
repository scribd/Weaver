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
    private let locker = NSLock()
    
    init(scope: Scope, body: Any) {
        self.scope = scope
        self.body = body
    }
    
    func functor<P, I>() -> (() -> P) -> I {
        
        guard let body = body as? (() -> P) -> I else {
            fatalError("Type \(((() -> P) -> I).self) doesn't correspond to body type: \(self.body.self)")
        }
        
        guard !scope.isTransient else {
            return body
        }
        
        return { (parameters: () -> P) -> I in
            self.locker.lock()
            defer { self.locker.unlock() }
            
            if let instance = self.instance?.value as? I {
                return instance
            }
            
            let instance = body(parameters)
            self.instance = Instance(value: instance as AnyObject, scope: self.scope)
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
