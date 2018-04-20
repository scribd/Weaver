//
//  Dependencies.swift
//  Weaver
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation

public class Dependencies {
    
    private let container: DependencyContainer
    
    // MARK: - Inits
    
    init(_ container: DependencyContainer) {
        self.container = container

        registerDependencies(in: container)
    }
    
    public convenience init() {
        self.init(DependencyContainer())
    }
    
    // MARK: API
    
    public func registerDependencies(in store: DependencyStore) {
        fatalError("\(Dependencies.self): \(#function) needs to be overriden.")
    }
}
