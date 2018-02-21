//
//  InstanceKeyTests.swift
//  BeaverDITests
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation
import XCTest

@testable import BeaverDI

final class InstanceKeyTests: XCTestCase {
    
    func testInstanceKeys() {
        
        XCTAssertEqual(InstanceKey(for: Int.self).description, "Int")
        XCTAssertEqual(InstanceKey(for: Int.self, parameterType: String.self).description, "Int(String)")
        XCTAssertEqual(InstanceKey(for: Int.self, parameterTypes: String.self, String.self).description, "Int(String,String)")
        XCTAssertEqual(InstanceKey(for: Int.self, parameterTypes: String.self, String.self, String.self).description, "Int(String,String,String)")
        XCTAssertEqual(InstanceKey(for: Int.self, parameterTypes: String.self, String.self, String.self, String.self).description, "Int(String,String,String,String)")
    }
}
