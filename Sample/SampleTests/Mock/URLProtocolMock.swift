//
//  URLProtocolMock.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Sample

final class URLProtocolMock: URLProtocol {
    
    // MARK: - Stubs
    
    static var responseStubs = [(select: (URLRequest) -> Bool, stub: Result<URLResponse, URLError>)]()
    
    // MARK: - Spies
    
    private(set) static var requestsSpy = [URLRequest]()
    
    static func clearSpies() {
        URLProtocolMock.requestsSpy = []
        URLProtocolMock.responseStubs = []
    }
    
    // MARK: - Mocks
    
    override class func canInit(with request: URLRequest) -> Bool {
        URLProtocolMock.requestsSpy.append(request)
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let responseStub = URLProtocolMock.responseStubs.first(where: { $0.select(request) })?.stub else {
            XCTFail("Unexpected request: \(request)")
            return
        }
        
        switch responseStub {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
            
        case .success(let response):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {
        //do nothing
    }
}
