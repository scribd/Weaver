//
//  ThreadSafeBuilderStoringDecorator.swift
//  WeaverDIPackageDescription
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

final class ThreadSafeBuilderStoreDecorator: BuilderStoring {
    
    private let builders: BuilderStoring
    private let queue: DispatchQueue = DispatchQueue(label: "\(ThreadSafeBuilderStoreDecorator.self)")
    
    init(builders: BuilderStoring) {
        self.builders = builders
    }
    
    func get<B>(for key: InstanceKey, isCalledFromAChild: Bool) -> B? {
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        var getValue: B? = nil
        
        self.queue.async {
            getValue = self.builders.get(for: key, isCalledFromAChild: isCalledFromAChild)
            semaphore.signal()
        }
        
        semaphore.wait()
        return getValue
    }
    
    func set<B>(builder: B, scope: Scope, for key: InstanceKey) {
        self.queue.async {
            self.builders.set(builder: builder, scope: scope, for: key)
        }
    }
    
    var parent: BuilderStoring? {
        get {
            return self.builders.parent
        }
        set {
            self.builders.parent = newValue
        }
    }
}

