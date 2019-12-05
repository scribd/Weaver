//
//  Cache.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 12/4/19.
//

import Foundation
import PathKit

public final class LexerCache {
    
    struct Cache {
        
        struct Token {
            let value: AnyTokenBox
        }
        
        struct Value {
            let lastUpdate: Date
            let tokens: [Token]
        }
        
        let version: String
        var values: [String: Value]
    }

    private let cachePath: Path
    
    private let version: String

    private let shouldLog: Bool
    
    private var cache: Cache

    public init(for cachePath: Path,
                version: String,
                shouldLog: Bool = true) {
        
        self.cachePath = cachePath
        self.version = version
        self.shouldLog = shouldLog
        
        do {
            let cacheData: Data = try cachePath.read()
            cache = try JSONDecoder().decode(LexerCache.Cache.self, from: cacheData)
            
            if cache.version != version {
                if shouldLog {
                    print("Invalid cache. Creating a new one.")
                }
                clear()
            }
            
        } catch {
            if shouldLog {
                print("Could not read cache. \(error.localizedDescription) Creating a new one.")
            }
            cache = Cache(version: version, values: [:])
        }
    }
    
    public func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = .prettyPrinted
            #endif
            let cacheData = try encoder.encode(cache)
            if cachePath.exists {
                try cachePath.delete()
            }
            try cachePath.write(cacheData)
        } catch {
            if shouldLog {
                print("Could not save to disk. \(error.localizedDescription)")
            }
        }
    }
    
    public func clear() {
        cache = Cache(version: version, values: [:])
    }

    func read(for filePath: Path) -> [AnyTokenBox]? {
        do {
            let resourceValues = try filePath.url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey])

            guard let lastUpdate = resourceValues.contentModificationDate else {
                fail(for: filePath)
                return nil
            }
            
            guard let value = cache.values[key(for: filePath)] else {
                return nil
            }
            
            guard lastUpdate <= value.lastUpdate else {
                cache.values[key(for: filePath)] = nil
                return nil
            }
            
            return value.tokens.map { $0.value }
        } catch {
            fail(for: filePath, error)
            return nil
        }
    }
    
    func write(_ tokens: [AnyTokenBox], for filePath: Path) {
        cache.values[key(for: filePath)] = Cache.Value(
            lastUpdate: Date(),
            tokens: tokens.map { Cache.Token(value: $0) }
        )
    }
    
    private func key(for filePath: Path) -> String {
        if filePath.absolute().parent().string.starts(with: cachePath.absolute().parent().string) {
            return filePath.absolute().string.replacingOccurrences(of: cachePath.absolute().parent().string + "/", with: "")
        } else {
            return filePath.string
        }
    }
    
    private func fail(for filePath: Path, _ error: Error? = nil) {
        cache.values[key(for: filePath)] = nil
        if shouldLog {
            let errorMessage: String
            if let error = error {
                errorMessage = ": \(error.localizedDescription)"
            } else {
                errorMessage = "."
            }
            print("Could not read cache at path: \(filePath)\(errorMessage)")
        }
    }
}
