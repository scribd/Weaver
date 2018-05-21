//
//  ResolverSpies.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

@testable import Sample

final class MovieAPIDependencyResolverSpy: MovieAPIDependencyResolver {
    
    init() {
        URLProtocolSpy.clearSpies()
    }
    
    deinit {
        URLProtocolSpy.clearSpies()
    }
    
    // MARK: - Spies
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolSpy.self]
        return URLSession(configuration: config)
    }()
}

final class MovieManagerDependencyResolverSpy: MovieManagerDependencyResolver {
    
    // MARK: - Spies

    var movieAPISpy = APISpy()
    
    var movieAPI: APIProtocol {
        return movieAPISpy
    }
}

final class ImageManagerDependencyResolverSpy: ImageManagerDependencyResolver {
    
    init() {
        URLProtocolSpy.clearSpies()
    }

    deinit {
        URLProtocolSpy.clearSpies()
    }
    
    // MARK: - Spies
    
    var movieAPISpy = APISpy()

    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolSpy.self]
        return URLSession(configuration: config)
    }()
    
    var movieAPI: APIProtocol {
        return movieAPISpy
    }
}
