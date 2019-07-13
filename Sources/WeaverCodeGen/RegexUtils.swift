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

enum Patterns {
    private static let spaces = "\\s*"
    private static let equal = "\(spaces)=\(spaces)"
    private static let arrow = "\(spaces)<-\(spaces)"
    private static let name = "\\w+"
    private static let typeNamePart = "\(name)(\\.\(name))*"
    
    static let typeName = "(\(genericType))|(\(arrayType))|(\(dictType))"
    static let genericTypePart = "<\(typeNamePart)(\(spaces),\(spaces)\(typeNamePart))*>"
    static let genericType = "(\(typeNamePart))(\(genericTypePart))?\\??"
    static let arrayType = "\\[\(spaces)(\(genericType)\\??)\(spaces)\\]\\??"
    static let arrayTypeWithNamedGroups = "\\[\(spaces)(?<value>\(genericType)\\??)\(spaces)\\]\\??"
    static let dictType = "\\[\(spaces)(\(genericType)\\??)\(spaces):\(spaces)(\(genericType)\\??)\(spaces)\\]\\??"
    static let dictTypeWithNamedGroups = "\\[\(spaces)(?<key>\(genericType)\\??)\(spaces):\(spaces)(?<value>\(genericType)\\??)\(spaces)\\]\\??"

    static let register = "^(\(name))\(equal)(\(typeName))\(spaces)(<-\(spaces)(\(typeName))\(spaces))?$"
    static let reference = "^(\(name))\(arrow)(\(typeName))\(spaces)$"
    static let parameter = "^(\(name))\(spaces)<=\(spaces)(\(typeName))\(spaces)$"
    static let scope = "^(\(name))\\.scope\(equal)\\.(\(name))\(spaces)$"
    static let configuration = "^(\(name))\\.(\(name))\(equal)(.*)\(spaces)$"
    static let `import` = "^import\\s+(\(name))\(spaces)$"
}
