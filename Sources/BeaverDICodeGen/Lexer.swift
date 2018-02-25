//
//  Lexer.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation
import SourceKittenFramework

/// An object responsible of generating the tokens
public final class Lexer {
    
    enum Error: Swift.Error {
        case invalidAnnotation(line: Int, underlyingError: TokenType.AnnotationType.Error)
    }
    
    private let file: File
    
    private lazy var lines: [Line] = self.file.lines
    
    public init(_ file: File) {
        self.file = file
    }
    
    /// Generates a sorted list of tokens
    func tokenize() throws -> [Token] {
        
        let sourceKitAST = try Structure(file: file).dictionary
        let sourceKitTokens = try SyntaxMap(file: file).tokens
        
        var line = lines.startIndex
        let tokens = tokenize(from: sourceKitAST, at: &line) + (try tokenize(from: sourceKitTokens))

        return tokens.sorted(by: tokenSortFunction)
    }
}

// MARK: - Utils

private extension Lexer {
    
    func tokenSortFunction(_ lhs: Token, _ rhs: Token) -> Bool {
        return lhs.offset < rhs.offset
    }
    
    func findNextLine(after line: Int, containing offset: Int) -> Int? {
        var currentLine = line
        while currentLine < lines.endIndex && !lines[currentLine].range.contains(offset) {
            currentLine = lines.index(after: currentLine)
        }
        guard line != lines.endIndex else {
            return nil
        }
        return currentLine
    }
    
    /// Tokenize declarations from the SourceKitAST
    func tokenize(from sourceKitAST: [String: SourceKitRepresentable], at line: inout Int) -> [Token] {
        var tokens = [Token]()

        let typeDeclaration = SourceKitDeclaration(sourceKitAST)
        
        if let typeDeclaration = typeDeclaration {
            var startToken = typeDeclaration.toToken

            if let nextLine = findNextLine(after: line, containing: Int(startToken.offset)) {
                line = nextLine
                startToken.line = line
            } else {
                return tokens
            }
            
            tokens += [startToken]
        }
        
        if let children = sourceKitAST[SwiftDocKey.substructure.rawValue] as? [[String: SourceKitRepresentable]] {
            for child in children {
                tokens += tokenize(from: child, at: &line)
            }
        }

        if let typeDeclaration = typeDeclaration, let endToken = typeDeclaration.endToken {
            var mutableEndToken = endToken
            
            if let nextLine = findNextLine(after: line, containing: endToken.offset) {
                line = nextLine
                mutableEndToken.line = line
            } else {
                return tokens
            }
            
            tokens += [mutableEndToken]
        }

        return tokens
    }
    
    /// Tokenize annotations from the SourceKit SyntaxTokens.
    func tokenize(from sourceKitTokens: [SyntaxToken]) throws -> [Token] {

        var currentLine = lines.startIndex
        return try sourceKitTokens.flatMap { syntaxToken in
            
            guard SyntaxKind(rawValue: syntaxToken.type) == .comment else {
                return nil
            }

            guard let nextLine = findNextLine(after: currentLine, containing: syntaxToken.offset) else {
                return nil
            }
            currentLine = nextLine

            let content = lines[currentLine].content

            do {
                guard let annotationType = try TokenType.AnnotationType(stringValue: content) else {
                    return nil
                }
                return Token(type: .annotation(annotationType),
                             offset: syntaxToken.offset,
                             length: syntaxToken.length,
                             line: currentLine)
            } catch let error as TokenType.AnnotationType.Error {
                throw Error.invalidAnnotation(line: currentLine, underlyingError: error)
            }
        }
    }
}

