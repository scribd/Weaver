//
//  ResolverMocks.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

@testable import Sample

final class MovieAPIDependencyResolverMock: MovieAPIDependencyResolver {
    
    init() {
        URLProtocolMock.clearSpies()
    }
    
    deinit {
        URLProtocolMock.clearSpies()
    }
    
    // MARK: - Mocks
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: config)
    }()
}

final class MovieManagerDependencyResolverMock: MovieManagerDependencyResolver {

    // MARK: - Stubs
    
    var movieAPIStub = APIMock()
    
    // MARK: - Mocks
    
    var movieAPI: APIProtocol {
        return movieAPIStub
    }
}

final class ImageManagerDependencyResolverMock: ImageManagerDependencyResolver {
    
    init() {
        URLProtocolMock.clearSpies()
    }

    deinit {
        URLProtocolMock.clearSpies()
    }
    
    // MARK: - Stubs
    
    var movieAPIStub = APIMock()
    
    // MARK: - Mocks
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: config)
    }()
    
    var movieAPI: APIProtocol {
        return movieAPIStub
    }
}
