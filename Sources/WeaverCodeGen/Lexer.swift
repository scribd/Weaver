//
//  Lexer.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/21/18.
//

import Foundation
import SourceKittenFramework
import PathKit

/// An object responsible of generating the tokens
public final class Lexer {
    
    private let file: File
    private let fileName: String
    
    private let cache: LexerCache?
    
    private lazy var lines: [Line] = self.file.lines
    
    public init(_ file: File,
                fileName: String,
                cache: LexerCache? = nil) {

        self.file = file
        self.fileName = fileName
        self.cache = cache
    }
    
    /// Generates a sorted list of tokens
    public func tokenize() throws -> [AnyTokenBox] {
        
        if let filePath = file.path, let tokens = cache?.read(for: Path(filePath)) {
            return tokens
        }
        
        let sourceKitAST = try Structure(file: file).dictionary
        let sourceKitTokens = try SyntaxMap(file: file).tokens
        
        var line = lines.startIndex

        let tokens = try [
            tokenize(from: sourceKitAST, at: &line),
            tokenize(from: sourceKitTokens),
            tokenize(from: file.lines)
        ].flatMap { $0 }.sorted(by: tokenSortFunction)
        
        if let filePath = file.path, let cache = cache {
            cache.write(tokens, for: Path(filePath))
        }
        
        return tokens
    }
}

// MARK: - Utils

private extension Lexer {
    
    func tokenSortFunction(_ lhs: AnyTokenBox, _ rhs: AnyTokenBox) -> Bool {
        return lhs.offset < rhs.offset
    }
    
    func findNextLine(after line: Int, containing offset: Int) -> Int? {
        var currentLine = line
        while currentLine < lines.endIndex && !lines[currentLine].range.contains(offset) {
            currentLine = lines.index(after: currentLine)
        }
        guard currentLine < lines.endIndex else {
            return nil
        }
        return currentLine
    }
    
    /// Tokenize declarations from the SourceKitAST
    func tokenize(from sourceKitAST: [String: SourceKitRepresentable], at line: inout Int) throws -> [AnyTokenBox] {
        do {
            var tokens = [AnyTokenBox]()

            let restOfLines = lines[line...].map { ($0.content, $0.range) }
            if let annotation = try SourceKitDependencyAnnotation(sourceKitAST, lines: restOfLines, file: file.path, line: line) {
                return try annotation.toTokens()
            }

            let typeDeclaration = try SourceKitTypeDeclaration(sourceKitAST, lineString: lines[line].content)
            
            if let typeDeclaration = typeDeclaration {
                var startToken = typeDeclaration.toToken

                if let nextLine = findNextLine(after: line, containing: Int(startToken.offset)) {
                    line = nextLine
                    if let _typeDeclaration = try SourceKitTypeDeclaration(sourceKitAST, lineString: lines[line].content) {
                        startToken = _typeDeclaration.toToken
                    }
                    startToken.line = line
                } else {
                    return tokens
                }
                
                tokens += [startToken]
            }
            
            if let children = sourceKitAST[SwiftDocKey.substructure.rawValue] as? [[String: SourceKitRepresentable]] {
                for child in children {
                    tokens += try tokenize(from: child, at: &line)
                }
            }

            if let typeDeclaration = typeDeclaration, let endToken = typeDeclaration.endToken {
                var mutableEndToken = endToken
                
                line = findNextLine(after: line, containing: endToken.offset) ?? lines.count - 1
                mutableEndToken.line = line
                
                tokens += [mutableEndToken]
            }

            return tokens
        } catch let error as TokenError {
            let location = FileLocation(line: line, file: file.path)
            throw LexerError.invalidAnnotation(location, underlyingError: error)
        } catch {
            throw error
        }
    }
    
    /// Tokenize annotations from the SourceKit SyntaxTokens.
    func tokenize(from sourceKitTokens: [SyntaxToken]) throws -> [AnyTokenBox] {

        var currentLine = lines.startIndex
        return try sourceKitTokens.compactMap { syntaxToken in
            
            guard SyntaxKind(rawValue: syntaxToken.type) == .comment else {
                return nil
            }

            guard let nextLine = findNextLine(after: currentLine, containing: syntaxToken.offset.value) else {
                return nil
            }
            currentLine = nextLine

            let content = lines[currentLine].content

            do {
                guard let token = try TokenBuilder.makeAnnotationToken(string: content,
                                                                       offset: syntaxToken.offset.value,
                                                                       length: syntaxToken.length.value,
                                                                       line: currentLine) else {
                    return nil
                }
                return token
            } catch let error as TokenError {
                throw LexerError.invalidAnnotation(FileLocation(line: currentLine, file: fileName), underlyingError: error)
            }
        }
    }
    
    func tokenize(from lines: [Line]) throws -> [AnyTokenBox] {
        return try (0..<lines.count).compactMap { index in
            let line = lines[index]
            guard let token = try ImportDeclaration.create(fromComment: line.content) else {
                return nil
            }
            return TokenBox<ImportDeclaration>(value: token,
                                               offset: line.range.location,
                                               length: line.content.count,
                                               line: index)
        }
    }
}

