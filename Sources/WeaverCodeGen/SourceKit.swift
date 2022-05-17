//
//  SourceKit.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

private enum Key: String {
    case accessibility = "key.accessibility"
    case attributes = "key.attributes"
    case attribute = "key.attribute"
}

private enum Value: String {
    case propertyWrapper = "source.decl.attribute._custom"
    case objc = "source.decl.attribute.objc"
    case argument = "source.lang.swift.expr.argument"
}

// MARK: - Annotation

struct SourceKitDependencyAnnotation {
    
    let file: String?
    let line: Int
    
    let annotationString: String
    let offset: Int
    let length: Int
    let name: String
    let abstractType: AbstractType
    
    private(set) var type: ConcreteType?
    private(set) var expectedParametersCount = 0
    private(set) var dependencyKind: Dependency.Kind?
    private(set) var accessLevel: AccessLevel = .default
    private(set) var configurationAttributes = [ConfigurationAttribute]()
    
    init?(_ dictionary: [String: Any],
          lines: [(content: String, range: NSRange)],
          file: String?,
          line: Int) throws {

        guard let kindString = dictionary[SwiftDocKey.kind.rawValue] as? String,
              let kind = SwiftDeclarationKind(rawValue: kindString),
              kind == .varInstance else {
            return nil
        }
        
        guard let offset = dictionary[SwiftDocKey.offset.rawValue] as? Int64 else {
            return nil
        }
        self.offset = Int(offset)
        
        guard let length = dictionary[SwiftDocKey.length.rawValue] as? Int64 else {
            return nil
        }
        self.length = Int(length)
        
        guard let name = dictionary[SwiftDocKey.name.rawValue] as? String else {
            return nil
        }
        self.name = name
        
        guard let typename = dictionary[SwiftDocKey.typeName.rawValue] as? String else {
            return nil
        }
        
        if let accessLevelString = dictionary[Key.accessibility.rawValue] as? String {
            accessLevel = AccessLevel(accessLevelString)
        } else {
            accessLevel = .default
        }
        
        guard let attributes = dictionary[Key.attributes.rawValue] as? [[String: Any]] else {
            return nil
        }
        
        guard let annotation = attributes.first(where: { $0[Key.attribute.rawValue] as? String == Value.propertyWrapper.rawValue }),
              let annotationOffset = annotation[SwiftDocKey.offset.rawValue] as? Int64,
              let annotationLength = annotation[SwiftDocKey.length.rawValue] as? Int64,
              let annotationLineStartIndex = lines.firstIndex(where: { $0.range.contains(Int(annotationOffset)) }),
              let annotationLineEndIndex = lines.firstIndex(where: { $0.range.contains(Int(annotationOffset + annotationLength)) }) else {
            return nil
        }
        
        self.file = file
        self.line = line + annotationLineStartIndex
        
        if attributes.contains(where: { $0[Key.attribute.rawValue] as? String == Value.objc.rawValue }) {
            configurationAttributes.append(ConfigurationAttribute.doesSupportObjc(value: true))
        }
        
        abstractType = try AbstractType(value: CompositeType(typename))

        let annotationString = lines[annotationLineStartIndex...annotationLineEndIndex]
            .map { $0.content.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        self.annotationString = annotationString
                
        guard try parseBuilder() else { return nil }
    }
        
    private mutating func parseBuilder() throws -> Bool {

        guard let annotationString = extractBuilderParametersString() else { return false }
        
        let dictionary = try Structure(file: File(contents: annotationString)).dictionary
        guard let structures = dictionary[SwiftDocKey.substructure.rawValue] as? [[String: Any]] else { return false }
        guard let structure = structures.first else { return false }
        
        guard let annotationTypeString = structure[SwiftDocKey.name.rawValue] as? String else { return false }
        guard annotationTypeString.lowercased().hasPrefix("weaver") else { return false }
        
        expectedParametersCount = Int(annotationTypeString.lowercased().replacingOccurrences(of: "weaverp", with: "")) ?? 0

        let arguments = (structure[SwiftDocKey.substructure.rawValue] as? [[String: Any]]) ?? []
        if arguments.isEmpty {
            let dependencyKindString = annotationString
                .replacingOccurrences(of: annotationTypeString, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            dependencyKind = Dependency.Kind(dependencyKindString)
        }

        for argument in arguments {
            guard argument[SwiftDocKey.kind.rawValue] as? String == Value.argument.rawValue else { continue }
            guard let offset = argument[SwiftDocKey.offset.rawValue] as? Int64 else { continue }
            guard let length = argument[SwiftDocKey.length.rawValue] as? Int64 else { continue }

            if let attributeName = argument[SwiftDocKey.name.rawValue] as? String {
                let startIndex = annotationString.index(annotationString.startIndex, offsetBy: Int(offset))
                let endIndex = annotationString.index(startIndex, offsetBy: Int(length))
                let keyValueString = String(annotationString[startIndex..<endIndex])
                var keyValue = keyValueString.split(separator: ":")
                if keyValue.count > 1 {
                    keyValue.removeFirst()
                }
                let value = keyValue
                    .joined(separator: ":")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if attributeName == "type" {
                    let value = value.replacingOccurrences(of: ".self", with: "")
                    type = try ConcreteType(value: CompositeType(value))
                } else {
                    configurationAttributes.append(
                        try ConfigurationAttribute(name: attributeName, valueString: value)
                    )
                }
            } else {
                let startIndex = annotationString.index(annotationString.startIndex, offsetBy: Int(offset))
                let endIndex = annotationString.index(startIndex, offsetBy: Int(length))
                let valueString = String(annotationString[startIndex..<endIndex])
                dependencyKind = Dependency.Kind(valueString)
            }
        }
        
        return true
    }
    
    private func extractBuilderParametersString() -> String? {
        guard var startIndex = annotationString.firstIndex(of: "@") else { return nil }
        
        var iterator = annotationString.enumerated().makeIterator()
        var parenthesisCount = -1
        var endIndex = annotationString.startIndex
        while let (offset, char) = iterator.next(), parenthesisCount != 0 {
            if char == "(" {
                parenthesisCount = parenthesisCount == -1 ? 1 : parenthesisCount + 1
            } else if char == ")" {
                parenthesisCount -= 1
            }
            endIndex = annotationString.index(annotationString.startIndex, offsetBy: offset)
        }
        
        guard annotationString[startIndex] == "@" else { return nil }
        startIndex = annotationString.index(after: startIndex)
        endIndex = annotationString.index(after: endIndex)
        guard startIndex < endIndex, endIndex <= annotationString.endIndex else { return nil }
        return String(self.annotationString[startIndex..<endIndex])
    }
}

// MARK: - Type

struct SourceKitTypeDeclaration {
    
    let offset: Int
    let length: Int
    let type: ConcreteType
    let hasBody: Bool
    let accessLevel: AccessLevel
    let isInjectable: Bool
    
    init?(_ dictionary: [String: Any], classPath: String?, lineString: String) throws {
        
        guard let kindString = dictionary[SwiftDocKey.kind.rawValue] as? String,
              let kind = SwiftDeclarationKind(rawValue: kindString) else {
            return nil
        }
        
        guard let offset = dictionary[SwiftDocKey.offset.rawValue] as? Int64 else {
            return nil
        }
        self.offset = Int(offset)
        
        guard let length = dictionary[SwiftDocKey.length.rawValue] as? Int64 else {
            return nil
        }
        self.length = Int(length)

        switch kind {
        case .class,
             .struct:
            isInjectable = true
        case .enum,
             .extension:
            isInjectable = false
        default:
            return nil
        }

        guard var typeString = dictionary[SwiftDocKey.name.rawValue] as? String else {
            return nil
        }
        
        let components = lineString.components(separatedBy: typeString)
        if components.count > 1 {
            typeString += components[1]
        }

        let typeName = classPath.flatMap { "\($0).\(typeString)" } ?? typeString
        type = try ConcreteType(value: CompositeType(typeName))
        
        hasBody = dictionary.keys.contains(SwiftDocKey.bodyOffset.rawValue)
        
        if let attributeKindString = dictionary[Key.accessibility.rawValue] as? String {
            accessLevel = AccessLevel(attributeKindString)
        } else {
            accessLevel = .default
        }
    }
}

// MARK: - Conversion

private extension Int {
    /// Default value used until the real value gets determined later on.
    static let defaultLine = -1
}

extension SourceKitDependencyAnnotation {
        
    func toTokens() throws -> [AnyTokenBox] {
        let tokenBox: AnyTokenBox
        switch dependencyKind {
        case .registration:
            let (_abstractType, closureParameters) = try buildAbstractType()
            let concreteType = type ?? _abstractType.concreteType
            let abstractType = _abstractType.concreteType != concreteType ? _abstractType : AbstractType()
            
            let annotation = RegisterAnnotation(style: .propertyWrapper,
                                                name: name,
                                                type: concreteType,
                                                abstractType: abstractType,
                                                closureParameters: closureParameters)
 
            tokenBox = TokenBox(value: annotation,
                                offset: offset,
                                length: length,
                                line: line)
        case .parameter:
            guard let type = abstractType.first, abstractType.count == 1, self.type == nil else {
                throw LexerError.invalidAnnotation(FileLocation(line: line, file: file),
                                                   underlyingError: TokenError.invalidAnnotation(annotationString))
            }
            let annotation = ParameterAnnotation(style: .propertyWrapper,
                                                 name: name,
                                                 type: type.concreteType)
            tokenBox = TokenBox(value: annotation,
                                offset: offset,
                                length: length,
                                line: line)
            
        case .reference:
            let (abstractType, closureParameters) = try buildAbstractType()

            guard abstractType.isEmpty == false, type == nil else {
                throw LexerError.invalidAnnotation(FileLocation(line: line, file: file),
                                                   underlyingError: TokenError.invalidAnnotation(annotationString))
            }
            
            let annotation = ReferenceAnnotation(style: .propertyWrapper,
                                                 name: name,
                                                 type: abstractType,
                                                 closureParameters: closureParameters)
            tokenBox = TokenBox(value: annotation,
                                offset: offset,
                                length: length,
                                line: line)
            
        case .none:
            throw LexerError.invalidAnnotation(FileLocation(line: line, file: file),
                                               underlyingError: TokenError.invalidAnnotation(annotationString))
        }
        
        return [tokenBox] + configurationAttributes.map { attribute in
            let annotation = ConfigurationAnnotation(attribute: attribute, target: .dependency(name: name))
            return TokenBox(value: annotation,
                            offset: offset,
                            length: length,
                            line: line)
        }
    }
    
    private func buildAbstractType() throws -> (AbstractType, [TupleComponent]) {
        if let closure = self.abstractType.value.closure, expectedParametersCount > 0 {
            let abstractType = AbstractType(value: closure.returnType)
            let closureParameters = closure.tuple
            
            guard closureParameters.count == expectedParametersCount else {
                throw LexerError.invalidAnnotation(FileLocation(line: line, file: file),
                                                   underlyingError: TokenError.invalidAnnotation(annotationString))
            }
            
            return (abstractType, closureParameters)
        } else {
            return (abstractType, [])
        }
    }

}

extension SourceKitTypeDeclaration {
    
    var toToken: AnyTokenBox {
        if isInjectable {
            let injectableType = InjectableType(type: type, accessLevel: accessLevel)
            return TokenBox(value: injectableType, offset: offset, length: length, line: .defaultLine)
        } else {
            return TokenBox(value: AnyDeclaration(), offset: offset, length: length, line: .defaultLine)
        }
    }
    
    var endToken: AnyTokenBox? {
        guard hasBody == true else {
            return nil
        }
        
        let offset = self.offset + length - 1
        if isInjectable {
            return TokenBox(value: EndOfInjectableType(), offset: offset, length: 1, line: .defaultLine)
        } else {
            return TokenBox(value: EndOfAnyDeclaration(), offset: offset, length: 1, line: .defaultLine)
        }
    }
}

private extension AccessLevel {

    init(_ stringValue: String) {
        guard let value = AccessLevel.allCases.first(where: { stringValue.contains($0.rawValue) }) else {
            self = .internal
            return
        }
        self = value
    }
}

private extension Dependency.Kind {
    
    init?(_ stringValue: String) {
        guard let value = Dependency.Kind.allCases.first(where: { stringValue.contains($0.rawValue) }) else {
            return nil
        }
        self = value
    }
}
