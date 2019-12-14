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
    static let register = "^(\\w+)\\s*=\\s*(.+)?"
    static let reference = "^(\\w+)\\s*<-\\s*(.+)"
    static let parameter = "^(\\w+)\\s*<=\\s*(.+)"
    static let scope = "^(\\w+)\\.scope\\s*=\\s*\\.(\\w+)"
    static let configuration = "^(\\w+)\\.(\\w+)\\s*=\\s*(.+)"
    static let `import` = "^import\\s+(\\w+)"
    static let snakeCased = "([a-z0-9])([A-Z])"
}

extension NSRegularExpression {
    static let register = try! NSRegularExpression(pattern: Patterns.register)
    static let reference = try! NSRegularExpression(pattern: Patterns.reference)
    static let parameter = try! NSRegularExpression(pattern: Patterns.parameter)
    static let scope = try! NSRegularExpression(pattern: Patterns.scope)
    static let configuration = try! NSRegularExpression(pattern: Patterns.configuration)
    static let `import` = try! NSRegularExpression(pattern: Patterns.`import`)
    static let snakeCased = try! NSRegularExpression(pattern: Patterns.snakeCased)
}
