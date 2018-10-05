//
//  Logger.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import Darwin

// MARK: - Level

enum LogLevel {
    case info
    case error
}

extension LogLevel: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .info:
            return "[ INFO  ]"
        case .error:
            return "[ ERROR ]"
        }
    }
    
    var output: UnsafeMutablePointer<FILE> {
        switch self {
        case .info:
            return __stdoutp
        case .error:
            return __stderrp
        }
    }
}

// MARK: - Benchmark

enum Benchmark {
    case start(String)
    case end(String)
    case none
    
    fileprivate static var lastMessageDatesByID: [String: Date] = [:]
}

// MARK: - Logger

enum Logger {
    
    static func log(_ level: LogLevel,
                    _ message: String,
                    benchmark: Benchmark = .none,
                    function: StaticString = #function,
                    line: Int = #line) {
        
        var s = ""
        #if DEBUG
        s += "\(level) - function: \(function), line: \(line) - "
        #endif
        s += message
        
        switch benchmark {
        case .start(let identifier):
            Benchmark.lastMessageDatesByID[identifier] = Date()

        case .end(let identifier):
            if let lastMessageDate = Benchmark.lastMessageDatesByID[identifier] {
                s += " - " + "Executed in \(String(format: "%.4f", abs(lastMessageDate.timeIntervalSinceNow)))s.".lightBlack
            }
            Benchmark.lastMessageDatesByID.removeValue(forKey: identifier)
            
        case .none:
            break
        }
        
        s += "\n"
        fputs(s, level.output)
    }
}
