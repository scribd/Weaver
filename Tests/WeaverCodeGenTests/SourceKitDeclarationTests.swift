//
//  SourceKitDeclarationTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class SourceKitDeclarationTests: XCTestCase {
    
    private func makeModel(accessLevel: String = "source.lang.swift.accessibility.internal",
                           kind: String = "source.lang.swift.decl.class",
                           length: Int = 42,
                           offset: Int = 42,
                           bodyOffset: Int? = 42,
                           name: String = "fake_name",
                           inheritedType: String? = nil) -> SourceKitDeclaration? {

        let jsonString = """
{
  "key.accessibility" : "\(accessLevel)",
  "key.attributes" : [
    {
      "key.attribute" : "source.decl.attribute.final"
    }
  ],
  "key.bodylength" : 707,
  \(bodyOffset.flatMap { "\"key.bodyoffset\" : \($0)," } ?? "")
  "key.kind" : "\(kind)",
  "key.length" : \(length),
  "key.name" : "\(name)",
  "key.offset" : \(offset),
  "key.inheritedtypes" : [
    \(inheritedType.flatMap { "{ \"key.name\": \"\($0)\" }" } ?? "")
  ]
}
"""
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to build data from string: \(jsonString)")
            return nil
        }
        
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                XCTFail("Failed to dictionary from json: \(jsonString)")
                return nil
            }
            return SourceKitDeclaration(jsonObject)
        } catch {
            XCTFail("Unexpected json parsing error: \(error)")
            return nil
        }
    }
    
    // MARK: - length
    
    func test_init_should_set_length() {

        let model = makeModel(length: 42)
        XCTAssertEqual(model?.length, 42)
    }
    
    // MARK: - offset
    
    func test_init_should_set_offset() {
        
        let model = makeModel(offset: 42)
        XCTAssertEqual(model?.offset, 42)
    }
    
    // MARK: - name
    
    func test_init_should_set_name() {
     
        let model = makeModel(name: "fake_name")
        XCTAssertEqual(model?.type, SwiftType(name: "fake_name"))
    }
    
    // MARK: - isInjectable
    
    func test_init_should_set_isInjectable_to_true_if_kind_is_class() {

        let model = makeModel(kind: "source.lang.swift.decl.class")
        XCTAssertEqual(model?.isInjectable, true)
    }
    
    func test_init_should_set_isInjectable_to_true_if_kind_is_struct() {
        
        let model = makeModel(kind: "source.lang.swift.decl.struct")
        XCTAssertEqual(model?.isInjectable, true)
    }

    func test_init_should_set_isInjectable_to_false_if_kind_is_enum() {
        
        let model = makeModel(kind: "source.lang.swift.decl.enum")
        XCTAssertEqual(model?.isInjectable, false)
    }
    
    func test_init_should_set_isInjectable_to_true_if_kind_is_extension_of_ObjCDependencyInjectable() {
        
        let model = makeModel(kind: "source.lang.swift.decl.extension", inheritedType: "FakeObjCDependencyInjectable")
        XCTAssertEqual(model?.isInjectable, true)
    }
    
    func test_init_should_set_isInjectable_to_false_if_kind_is_extension_wihout_Injectable_inheritance() {
        
        let model = makeModel(kind: "source.lang.swift.decl.extension")
        XCTAssertEqual(model?.isInjectable, false)
    }
    
    // MARK: - - doesSupportObjc
    
    func test_init_should_set_doesSupportObjc_to_false_if_kind_is_class() {
        
        let model = makeModel(kind: "source.lang.swift.decl.class")
        XCTAssertEqual(model?.doesSupportObjc, false)
    }
    
    func test_init_should_set_doesSupportObjc_to_false_if_kind_is_struct() {
        
        let model = makeModel(kind: "source.lang.swift.decl.struct")
        XCTAssertEqual(model?.doesSupportObjc, false)
    }
    
    func test_init_should_set_doesSupportObjc_to_false_if_kind_is_enum() {
        
        let model = makeModel(kind: "source.lang.swift.decl.enum")
        XCTAssertEqual(model?.doesSupportObjc, false)
    }
    
    func test_init_should_set_doesSupportObjc_to_true_if_kind_is_extension_of_ObjCDependencyInjectable() {
        
        let model = makeModel(kind: "source.lang.swift.decl.extension", inheritedType: "FakeObjCDependencyInjectable")
        XCTAssertEqual(model?.doesSupportObjc, true)
    }
    
    func test_init_should_set_doesSupportObjc_to_false_if_kind_is_extension_wihout_ObjCDependencyInjectable_inheritance() {
        
        let model = makeModel(kind: "source.lang.swift.decl.extension")
        XCTAssertEqual(model?.doesSupportObjc, false)
    }
    
    // MARK: - hasBody
    
    func test_init_should_set_hasBody_to_true_if_bodyOffset_is_defined() {
        
        let model = makeModel(bodyOffset: 42)
        XCTAssertEqual(model?.hasBody, true)
    }
    
    func test_init_should_set_hasBody_to_false_if_bodyOffset_is_not_defined() {
        
        let model = makeModel(bodyOffset: nil)
        XCTAssertEqual(model?.hasBody, false)
    }
    
    // MARK: - accessLevel
    
    func test_init_should_set_accessLevel_to_default_if_accessLevel_is_not_supported() {
        
        let model = makeModel(accessLevel: "source.lang.swift.accessibility.fileprivate")
        XCTAssertEqual(model?.accessLevel, .default)
    }
    
    func test_init_shold_set_accessLevel_to_internal_if_accessLevel_is_internal() {
        
        let model = makeModel(accessLevel: "source.lang.swift.accessibility.internal")
        XCTAssertEqual(model?.accessLevel, .internal)
    }
    
    func test_init_shold_set_accessLevel_to_public_if_accessLevel_is_public() {
        
        let model = makeModel(accessLevel: "source.lang.swift.accessibility.public")
        XCTAssertEqual(model?.accessLevel, .public)
    }
}
