//
//  MovieAPITests.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import API

final class MovieAPITests: XCTestCase {

    var movieAPIDependencyResolverSpy: MovieAPIDependencyResolverSpy!
    
    var movieAPI: MovieAPI!
    
    override func setUp() {
        super.setUp()
        
        movieAPIDependencyResolverSpy = MovieAPIDependencyResolverSpy()
        movieAPI = MovieAPI(injecting: movieAPIDependencyResolverSpy)
    }
    
    override func tearDown() {
        defer {
            super.tearDown()
        }
        
        movieAPIDependencyResolverSpy = nil
        movieAPI = nil
    }
    
    // MARK: - send(request:completion)
    
    func test_sendDataRequest_should_call_urlSession_and_succeed() {

        let responseData = "{}".data(using: .utf8)!
        let responseURL = URL(dataRepresentation: responseData, relativeTo: nil)!
        let responseStub = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Length": responseData.count.description])!
        let selectResponse = { (request: URLRequest) -> Bool in
            return request.url?.host == "test" && request.url?.path == "/test"
        }
        URLProtocolSpy.responseStubs.append((select: selectResponse, stub: .success(responseStub)))
        
        let request = APIRequest<Data>(method: .get, host: "http://test", path: "/test")
        
        let expectation = self.expectation(description: "send")
        
        movieAPI.send(request: request) { result in
            XCTAssertNotNil(URLProtocolSpy.requestsRecord.first)

            switch result {
            case .success:
                break
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
