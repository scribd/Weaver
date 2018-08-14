//
//  Configuration.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/7/18.
//

import Foundation

// MARK: - Configuration

protocol Configuration {
    
    init(with attributes: [ConfigurationAttributeName: ConfigurationAttribute]?)
}

extension Configuration {
    
    init(with attributes: [ConfigurationAttribute]?) {
        let dict = [ConfigurationAttributeName: ConfigurationAttribute]()
        let configDict = attributes?.reduce(into: dict) { dict, attribute in
            dict[attribute.name] = attribute
        }
        self.init(with: configDict)
    }
    
    init(with annotations: [ConfigurationAnnotation]?) {
        self.init(with: annotations?.map { $0.attribute })
    }
    
    static var empty: Self {
        return Self(with: nil)
    }
}

// MARK: - Implementations

struct DependencyConfiguration: Configuration {
    
    let customRef: Bool
    
    let scope: Scope
    
    init(with attributes: [ConfigurationAttributeName: ConfigurationAttribute]?) {
        customRef = attributes?[.customRef]?.boolValue ?? false
        scope = attributes?[.scope]?.scopeValue ?? .default
    }
}

struct DependencyContainerConfiguration: Configuration {
    
    let isIsolated: Bool
    
    init(with attributes: [ConfigurationAttributeName: ConfigurationAttribute]?) {
        isIsolated = attributes?[.isIsolated]?.boolValue ?? false
    }
}
