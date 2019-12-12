//
//  SourceKitTypeTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

// MARK: - Annotation

final class SourceKitDependencyAnnotationTests: XCTestCase {
    
    private func makeModel(accessLevel: String = "source.lang.swift.accessibility.internal",
                           length: Int = 42,
                           offset: Int = 42,
                           bodyOffset: Int? = 42,
                           name: String = "fake_name",
                           abstractTypes: String = "FakeProtocol",
                           scope: String = "container",
                           setter: Bool = false,
                           builder: String? = nil,
                           type: String = "FakeType",
                           dependencyKind: String = "registration") throws -> SourceKitDependencyAnnotation? {

        let builder = builder.flatMap { ", builder: \($0)" } ?? ""
        let lineContent = """
@Weaver(.\(dependencyKind), type: \(type).self, scope: .\(scope), setter: \(setter)\(builder)) private var \(name): \(abstractTypes)
"""

        let jsonString = """
{
    "key.nameoffset" : 727,
    "key.typename" : "\(abstractTypes)",
    "key.setter_accessibility" : "\(accessLevel)",
    "key.namelength" : 8,
    "key.kind" : "source.lang.swift.decl.var.instance",
    "key.accessibility" : "\(accessLevel)",
    "key.name" : "\(name)",
    "key.attributes" : [
     {
        "key.offset" : 0,
        "key.length" : \(lineContent.count - 1),
        "key.attribute" : "source.decl.attribute._custom"
     }
    ],
    "key.offset" : \(offset),
    "key.length" : \(length)
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
            let line = (content: lineContent, range: NSRange(location: 0, length: lineContent.count))
            return try SourceKitDependencyAnnotation(jsonObject, lines: [line], file: "FakeFile.swift", line: 0)
        } catch {
            XCTFail("Unexpected json parsing error: \(error)")
            return nil
        }
    }
    
    func test_init_should_set_length() throws {
        let model = try makeModel(length: 42)
        XCTAssertEqual(model?.length, 42)
    }
    
    func test_init_should_set_offset() throws {
        let model = try makeModel(offset: 42)
        XCTAssertEqual(model?.offset, 42)
    }
    
    func test_init_should_set_name() throws {
        let model = try makeModel(name: "fake_name")
        XCTAssertEqual(model?.name, "fake_name")
    }
    
    func test_init_should_set_annotation_string() throws {
        let model = try makeModel()
        XCTAssertFalse(model?.annotationString.isEmpty ?? true)
    }
    
    func test_init_should_set_type() throws {
        let model = try makeModel(type: "FakeType")
        XCTAssertEqual(model?.type?.description, "FakeType")
    }
    
    func test_init_should_set_abtract_types() throws {
        let model = try makeModel(abstractTypes: "FakeProtocol1 & FakeProtocol2")
        XCTAssertEqual(model!.abstractTypes.sorted { $0.description < $1.description }.description, "[FakeProtocol1, FakeProtocol2]")
    }
    
    func test_init_should_set_dependency_kind_to_references() throws {
        let model = try makeModel(dependencyKind: "reference")
        XCTAssertEqual(model?.dependencyKind, .reference)
    }
    
    func test_init_should_set_dependency_kind_to_registration() throws {
        let model = try makeModel(dependencyKind: "registration")
        XCTAssertEqual(model?.dependencyKind, .registration)
    }

    func test_init_should_set_dependency_kind_to_parameters() throws {
        let model = try makeModel(dependencyKind: "parameter")
        XCTAssertEqual(model?.dependencyKind, .parameter)
    }
    
    func test_init_should_set_access_level_to_public() throws {
        let model = try makeModel(accessLevel: "source.lang.swift.accessibility.publics")
        XCTAssertEqual(model?.accessLevel, .public)
    }
    
    func test_init_should_set_access_level_to_open() throws {
        let model = try makeModel(accessLevel: "source.lang.swift.accessibility.open")
        XCTAssertEqual(model?.accessLevel, .open)
    }
    
    func test_init_should_set_access_level_to_internal() throws {
        let model = try makeModel(accessLevel: "source.lang.swift.accessibility.internal")
        XCTAssertEqual(model?.accessLevel, .internal)
    }
    
    func test_init_should_default_access_level_to_internal() throws {
        let model = try makeModel(accessLevel: "source.lang.swift.accessibility.fileprivate")
        XCTAssertEqual(model?.accessLevel, .internal)
    }
    
    func test_init_should_set_scope_to_weak() throws {
        let model = try makeModel(scope: "weak")
        let attribute = model?.configurationAttributes.first { $0.name == .scope }
        XCTAssertEqual(attribute?.scopeValue, .weak)
    }
    
    func test_init_should_set_scope_to_lazy() throws {
        let model = try makeModel(scope: "lazy")
        let attribute = model?.configurationAttributes.first { $0.name == .scope }
        XCTAssertEqual(attribute?.scopeValue, .lazy)
    }

    func test_init_should_set_scope_to_container() throws {
        let model = try makeModel(scope: "container")
        let attribute = model?.configurationAttributes.first { $0.name == .scope }
        XCTAssertEqual(attribute?.scopeValue, .container)
    }

    func test_init_should_set_scope_to_transient() throws {
        let model = try makeModel(scope: "transient")
        let attribute = model?.configurationAttributes.first { $0.name == .scope }
        XCTAssertEqual(attribute?.scopeValue, .transient)
    }
    
    func test_init_should_set_setter_to_true() throws {
        let model = try makeModel(setter: true)
        let attribute = model?.configurationAttributes.first { $0.name == .setter }
        XCTAssertEqual(attribute?.boolValue, true)
    }
}

// MARK: - Type

final class SourceKitTypeDeclarationTests: XCTestCase {
    
    private func makeModel(accessLevel: String = "source.lang.swift.accessibility.internal",
                           kind: String = "source.lang.swift.decl.class",
                           length: Int = 42,
                           offset: Int = 42,
                           bodyOffset: Int? = 42,
                           name: String = "fake_name") -> SourceKitTypeDeclaration? {

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
    "key.offset" : \(offset)
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
            return SourceKitTypeDeclaration(jsonObject)
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
        XCTAssertEqual(model?.type.description, "fake_name")
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
        
    func test_init_should_set_isInjectable_to_false_if_kind_is_extension_wihout_Injectable_inheritance() {
        
        let model = makeModel(kind: "source.lang.swift.decl.extension")
        XCTAssertEqual(model?.isInjectable, false)
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

