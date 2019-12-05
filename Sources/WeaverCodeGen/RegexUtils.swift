//
//  RegexUtils.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/22/18.
//

import Foundation

// MARK: - Regex Util

extension NSRegularExpression {
    
    func matches(in string: String) -> [String]? {
        let result = self
            .matches(in: string, range: NSMakeRange(0, string.utf16.count))
            .flatMap { match in (1..<match.numberOfRanges).map { match.range(at: $0) } }
            .compactMap { Range($0, in: string) }
            .map { String(string[$0]) }
        
        if result.isEmpty {
            return nil
        }
        return result
    }

    func firstMatch(in string: String) -> NSTextCheckingResult? {
        return matches(in: string, range: NSMakeRange(0, string.utf16.count)).first
    }
}

extension NSTextCheckingResult {

    func rangeString(at idx: Int, in string: String) -> String? {
        let nsRange = self.range(at: idx)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: string) else {
            return nil
        }

        return String(string[range])
    }

    func rangeString(withName name: String, in string: String) -> String? {
        let nsRange = self.range(withName: name)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: string) else {
            return nil
        }

        return String(string[range])
    }
}

// MARK: - Patterns

private enum Patterns {
    private static let spaces = "\\s*"
    private static let equal = "\(spaces)=\(spaces)"
    private static let arrow = "\(spaces)<-\(spaces)"
    private static let doubleArrow = "\(spaces)<=\(spaces)"
    private static let name = "\\w+"
    private static let typeNamePart = "\(name)(\\.\(name))*"

    private static let typeName = "(\(genericType))|(\(arrayType))|(\(dictType))"
    private static let arrayType = "\\[\(spaces)(\(genericType)\\??)\(spaces)\\]\\??"
    private static let dictType = "\\[\(spaces)(\(genericType)\\??)\(spaces):\(spaces)(\(genericType)\\??)\(spaces)\\]\\??"
    private static let variadicTypes = "(&\(spaces)\(typeName)\(spaces))*"

    static let arrayTypeWithNamedGroups = "\\[\(spaces)(?<value>\(genericType)\\??)\(spaces)\\]\\??"
    static let dictTypeWithNamedGroups = "\\[\(spaces)(?<key>\(genericType)\\??)\(spaces):\(spaces)(?<value>\(genericType)\\??)\(spaces)\\]\\??"
    static let genericTypePart = "<\(typeNamePart)(\(spaces),\(spaces)\(typeNamePart))*>"
    static let genericType = "(\(typeNamePart))(\(genericTypePart))?\\??"

    static let register = "^(\(name))\(equal)(\(typeName))\(spaces)(\(arrow)(\(typeName))\(spaces)\(variadicTypes))?$"
    static let reference = "^(\(name))\(arrow)(\(typeName))\(spaces)\(variadicTypes)$"
    static let parameter = "^(\(name))\(doubleArrow)(\(typeName))\(spaces)$"
    static let scope = "^(\(name))\\.scope\(equal)\\.(\(name))\(spaces)$"
    static let configuration = "^(\(name))\\.(\(name))\(equal)(.*)\(spaces)$"
    static let `import` = "^import\\s+(\(name))\(spaces)$"
    static let snakeCased = "([a-z0-9])([A-Z])"
}

extension NSRegularExpression {
    static let arrayTypeWithNamedGroups = try! NSRegularExpression(pattern: "^(\(Patterns.arrayTypeWithNamedGroups))$")
    static let dictTypeWithNamedGroups = try! NSRegularExpression(pattern: "^(\(Patterns.dictTypeWithNamedGroups))$")
    static let genericTypePart = try! NSRegularExpression(pattern: "(\(Patterns.genericTypePart))")
    static let genericType = try! NSRegularExpression(pattern: "^(\(Patterns.genericType))$")
    static let register = try! NSRegularExpression(pattern: Patterns.register)
    static let reference = try! NSRegularExpression(pattern: Patterns.reference)
    static let parameter = try! NSRegularExpression(pattern: Patterns.parameter)
    static let scope = try! NSRegularExpression(pattern: Patterns.scope)
    static let configuration = try! NSRegularExpression(pattern: Patterns.configuration)
    static let `import` = try! NSRegularExpression(pattern: Patterns.`import`)
    static let snakeCased = try! NSRegularExpression(pattern: Patterns.snakeCased)
}
