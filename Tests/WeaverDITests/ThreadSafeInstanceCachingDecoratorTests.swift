//
//  ThreadSafeInstanceCachingDecoratorTests.swift
//  WeaverDITests
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation

import XCTest

@testable import WeaverDI

class ThreadSafeInstanceCachingDecoratorTests: XCTestCase {
    
    
    let instanceKey = InstanceKey(for: String.self, name: "test")
    
    func builder() -> String {
        return "builder"
    }
    
    func test_set_should_delegate_to_inner_builder() {
        let cacheMock = InstanceCacheMock()
        
        let sut = ThreadSafeInstanceCachingDecorator(cache: cacheMock)
        
        _ = sut.cache(for: instanceKey, scope: .container, builder: self.builder)
        
        XCTAssertEqual(cacheMock.cacheCallCount, 1)
        XCTAssertEqual(cacheMock.scope, .container)
        XCTAssertEqual(cacheMock.key, instanceKey)
    }
    
    func test_many_access_in_parallel() {
        let cacheMock = InstanceCacheMock()
        let sut = ThreadSafeInstanceCachingDecorator(cache: cacheMock)
        
        for index in 1...1000 {
            DispatchQueue.main.async {
                
                let instanceKey = InstanceKey(for: String.self, name: "test_\(index)")
                let builder: () -> Int = {
                    return index
                }
                _ = sut.cache(for: instanceKey, scope: .container, builder: builder)
            }
            
            DispatchQueue.global(qos: .background).async {
                let instanceKey = InstanceKey(for: String.self, name: "test_background_\(index)")
                let builder: () -> Int = {
                    return index
                }
                _ = sut.cache(for: instanceKey, scope: .container, builder: builder)
            }
            
            DispatchQueue.global(qos: .userInteractive).async {
                let instanceKey = InstanceKey(for: String.self, name: "test_interactive_\(index)")
                let builder: () -> Int = {
                    return index
                }
                _ = sut.cache(for: instanceKey, scope: .container, builder: builder)
            }
        }
        
        waitDelay()
        
        XCTAssertEqual(cacheMock.cacheCallCount, 3000)
    }
    
    private func waitDelay() {
        let timeout = expectation(description: "Queue Dispatch Completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            timeout.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
}
