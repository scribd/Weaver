//
//  ThreadSafeBuilderStoringDecorator.swift
//  WeaverDIPackageDescription
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

class ThreadSafeBuilderStoringDecorator: BuilderStoring {
    
    let builderStoring: BuilderStore
    private let queue: DispatchQueue = DispatchQueue(label: "ThreadSafeBuilderStoringDecorator")
    
    init(builderStoring: BuilderStore) {
        self.builderStoring = builderStoring
    }
    
    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B? {
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        var getValue: B? = nil
        
        self.queue.async {
            getValue = self.builderStoring.get(for: key, isCalledFromAChild: isCalledFromAChild)
            semaphore.signal()
        }
        
        semaphore.wait()
        return getValue
    }
    
    func set<B>(builder: B, scope: Scope, for key: InstanceKey) {
        self.queue.async {
            self.builderStoring.set(builder: builder, scope: scope, for: key)
        }
    }
    
    var parent: BuilderStoring? {
        get {
            return self.builderStoring.parent
        }
        set {
            self.builderStoring.parent = newValue
        }
    }
}

