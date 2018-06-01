//
//  ThreadSafeBuilderStoringDecoratorTests.swift
//  WeaverDITests
//
//  Created by Bruno Mazzo on 5/31/18.
//

import Foundation
import XCTest

@testable import WeaverDI

class ThreadSafeBuilderStoringDecoratorTests: XCTestCase {
    

    let instanceKey = InstanceKey(for: String.self, name: "test")
    
    func builder() -> String {
        return "builder"
    }
    
    func test_set_should_delegate_to_inner_builder() {
        let builderMock = BuilderStoreMock()
        
        let sut = ThreadSafeBuilderStoringDecorator(builderStoring: builderMock)
        sut.set(builder: builder, scope: .container, for: instanceKey)
        
        waitDelay()
        
        XCTAssertEqual(builderMock.setCallCount, 1)
        XCTAssertEqual((builderMock.builder as? ()->String)?(), "builder")
        XCTAssertEqual(builderMock.scope, .container)
        XCTAssertEqual(builderMock.key, instanceKey)
    }
    
   
    func test_get_should_delegate_to_inner_builder() {
        let builderMock = BuilderStoreMock()
        
        let sut = ThreadSafeBuilderStoringDecorator(builderStoring: builderMock)
        sut.set(builder: builder, scope: .container, for: instanceKey)
        
        let result: (()-> String)? = sut.get(for: instanceKey, isCalledFromAChild: true)
                
        XCTAssertEqual(builderMock.getCallCount, 1)
        XCTAssertEqual(result?(), "builder")
        XCTAssertEqual(builderMock.key, instanceKey)
    }
    
    func test_many_access_in_parallel() {
        let builderMock = BuilderStoreMock()
        
        let sut = ThreadSafeBuilderStoringDecorator(builderStoring: builderMock)
        
        for index in 1...1000 {
            DispatchQueue.main.async {
                
                let instanceKey = InstanceKey(for: String.self, name: "test_\(index)")
                let builder: () -> Int = {
                    return index
                }
                sut.set(builder: builder, scope: .container, for: instanceKey)
            }
            
            DispatchQueue.global(qos: .background).async {
                let instanceKey = InstanceKey(for: String.self, name: "test_background_\(index)")
                let builder: () -> Int = {
                    return index
                }
                sut.set(builder: builder, scope: .container, for: instanceKey)
            }
            
            DispatchQueue.global(qos: .userInteractive).async {
                let instanceKey = InstanceKey(for: String.self, name: "test_interactive_\(index)")
                let builder: () -> Int = {
                    return index
                }
                sut.set(builder: builder, scope: .container, for: instanceKey)
            }
        }
        
        for index in 1...1000 {
            DispatchQueue.main.async {
                let instanceKey = InstanceKey(for: String.self, name: "test_\(index)")
                let _: (()-> Int)? = sut.get(for: instanceKey, isCalledFromAChild: true)
            }
            
            DispatchQueue.global(qos: .background).async {
                let instanceKey = InstanceKey(for: String.self, name: "test_background_\(index)")
                let _: (()-> Int)? = sut.get(for: instanceKey, isCalledFromAChild: true)
            }
        }
        
        waitDelay()
        
        XCTAssertEqual(builderMock.getCallCount, 2000)
        XCTAssertEqual(builderMock.setCallCount, 3000)
        
    }
    
    private func waitDelay() {
        let timeout = expectation(description: "Queue Dispatch Completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            timeout.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
}
