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
    
    let customBuilder: String?
    
    let scope: Scope
    
    let doesSupportObjc: Bool
    
    init(with attributes: [ConfigurationAttributeName: ConfigurationAttribute]?) {
        customBuilder = attributes?[.customBuilder]?.stringValue
        scope = attributes?[.scope]?.scopeValue ?? .default
        doesSupportObjc = attributes?[.doesSupportObjc]?.boolValue ?? false
    }
}

struct DependencyContainerConfiguration: Configuration {
    
    let isIsolated: Bool
    
    let doesSupportObjc: Bool
    
    init(with attributes: [ConfigurationAttributeName: ConfigurationAttribute]?) {
        isIsolated = attributes?[.isIsolated]?.boolValue ?? false
        doesSupportObjc = attributes?[.doesSupportObjc]?.boolValue ?? false
    }
}
