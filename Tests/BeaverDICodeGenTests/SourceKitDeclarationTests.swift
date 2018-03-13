//
//  SourceKitDeclarationTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import BeaverDICodeGen

final class SourceKitDeclarationTests: XCTestCase {
    
    func test_model_should_be_valid() {

        let json = """
{
  "key.accessibility" : "source.lang.swift.accessibility.internal",
  "key.attributes" : [
    {
      "key.attribute" : "source.decl.attribute.final"
    }
  ],
  "key.bodylength" : 707,
  "key.bodyoffset" : 81,
  "key.kind" : "source.lang.swift.decl.class",
  "key.length" : 725,
  "key.name" : "MyService",
  "key.namelength" : 9,
  "key.nameoffset" : 70,
  "key.offset" : 64,
  "key.runtime_name" : "_TtC8__main__9MyService",
  "key.substructure" : []
}
"""
        let data = json.data(using: .utf8)!
        let jsonObject = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
        let model = SourceKitDeclaration(jsonObject)
        
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.length, 725)
        XCTAssertEqual(model?.offset, 64)
        XCTAssertEqual(model?.name, "MyService")
        XCTAssertEqual(model?.isInjectable, true)
    }
    
    func test_model_should_be_invalid_when_kind_is_not_supported() {
        
        let json = """
{
  "key.accessibility" : "source.lang.swift.accessibility.internal",
  "key.attributes" : [
    {
      "key.attribute" : "source.decl.attribute.final"
    }
  ],
  "key.bodylength" : 707,
  "key.bodyoffset" : 81,
  "key.kind" : "source.lang.swift.decl.enum",
  "key.length" : 725,
  "key.name" : "MyService",
  "key.namelength" : 9,
  "key.nameoffset" : 70,
  "key.offset" : 64,
  "key.runtime_name" : "_TtC8__main__9MyService",
  "key.substructure" : []
}
"""
        
        let data = json.data(using: .utf8)!
        let jsonObject = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
        let model = SourceKitDeclaration(jsonObject)

        XCTAssertNotNil(model)
        XCTAssertEqual(model?.isInjectable, false)
    }
}
