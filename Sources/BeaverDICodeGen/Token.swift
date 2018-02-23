//
//  Token.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework

enum TokenType {
    
    enum AnnotationType {
        case parentResolver(type: String)
        case register(name: String, type: String)
        case resolve(String)
        case scope(name: String, scope: String)
    }
    
    case type
    case endOfType
    case annotation(AnnotationType)
    case star
}

struct Token {
    let type: TokenType
    let offset: Int
    let length: Int
    var line: Int
}

// MARK: - Annotations

extension TokenType.AnnotationType {
    
    enum Error: Swift.Error {
        case invalidAnnotation(String)
    }
    
    init?(stringValue: String) throws {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = stringValue.trimmingCharacters(in: chars)
        
        let bodyRegex = try NSRegularExpression(pattern: "^beaverdi *: *(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }
        
        if let value = try (
            TokenType.AnnotationType.makeParentResolverAnnotation(from: body) ??
            TokenType.AnnotationType.makeRegisterAnnotation(from: body) ??
            TokenType.AnnotationType.makeScopeAnnotation(from: body)
        ) {
            self = value
            return
        }
        
        throw Error.invalidAnnotation(annotation)
    }
}

// MARK: - Builders

private extension TokenType.AnnotationType {
    
    static func makeParentResolverAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^parent *= *(\\w+)").matches(in: string) else {
            return nil
        }
        return .parentResolver(type: matches[0])
    }
    
    static func makeRegisterAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+) *-> *(\\w+)").matches(in: string) else {
            return nil
        }
        return .register(name: matches[0], type: matches[1])
    }
    
    static func makeScopeAnnotation(from string: String) throws -> TokenType.AnnotationType? {
        guard let matches = try NSRegularExpression(pattern: "^(\\w+)\\.scope *= *\\.(\\w+)").matches(in: string) else {
            return nil
        }
        return .scope(name: matches[0], scope: matches[1])
    }
}

// MARK: Regex Util

private extension NSRegularExpression {
    
    func matches(in string: String) -> [String]? {
        let result = self
            .matches(in: string, range: NSMakeRange(0, string.utf16.count))
            .flatMap { match in (1..<match.numberOfRanges).map { match.range(at: $0) } }
            .flatMap { Range($0, in: string) }
            .map { String(string[$0]) }
        
        if result.isEmpty {
            return nil
        }
        return result
    }
}

