//
//  BuilderKeyTests.swift
//  WeaverTests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation
import XCTest

@testable import WeaverDI

final class BuilderKeyTests: XCTestCase {
    
    func test_instance_keys() {

        XCTAssertEqual(BuilderKey(for: Int.self, name: nil).description, "_:Int")
        XCTAssertEqual(BuilderKey(for: Int.self, name: "test").description, "test:Int")

        XCTAssertEqual(BuilderKey(for: Int.self, name: nil, parameterType: String.self).description, "_:Int(String)")
        XCTAssertEqual(BuilderKey(for: Int.self, name: "test", parameterType: String.self).description, "test:Int(String)")
        
        XCTAssertEqual(BuilderKey(for: Int.self, name: nil, parameterTypes: String.self, String.self).description, "_:Int(String,String)")
        XCTAssertEqual(BuilderKey(for: Int.self, name: "test", parameterTypes: String.self, String.self).description, "test:Int(String,String)")

        XCTAssertEqual(BuilderKey(for: Int.self, name: nil, parameterTypes: String.self, String.self, String.self).description, "_:Int(String,String,String)")
        XCTAssertEqual(BuilderKey(for: Int.self, name: "test", parameterTypes: String.self, String.self, String.self).description, "test:Int(String,String,String)")
        
        XCTAssertEqual(BuilderKey(for: Int.self, name: nil, parameterTypes: String.self, String.self, String.self, String.self).description, "_:Int(String,String,String,String)")
        XCTAssertEqual(BuilderKey(for: Int.self, name: "test", parameterTypes: String.self, String.self, String.self, String.self).description, "test:Int(String,String,String,String)")
    }
}
