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
}

// MARK: - Patterns

enum Patterns {
    private static let spaces = "\\s*"
    private static let equal = "\(spaces)=\(spaces)"
    private static let arrow = "\(spaces)<-\(spaces)"
    private static let name = "\\w+"
    
    static let typeName = "(\(name))(<\(name)(\(spaces),\(spaces)\(name))*>)?\\??"
    static let register = "^(\(name))\(equal)(\(typeName))\(spaces)(<-\(spaces)(\(typeName))\(spaces))?$"
    static let reference = "^(\(name))\(arrow)(\(typeName))\(spaces)$"
    static let parameter = "^(\(name))\(spaces)<=\(spaces)(\(typeName))\(spaces)$"
    static let scope = "^(\(name))\\.scope\(equal)\\.(\(name))\(spaces)$"
    static let configuration = "^(\(name))\\.(\(name))\(equal)(\(name)\\??)\(spaces)$"
    static let `import` = "^import\\s+(\(name))\(spaces)$"
}
