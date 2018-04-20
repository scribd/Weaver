//
//  Logger.swift
//  WeaverCommand
//
//  Created by Théophane Rupin on 3/7/18.
//

import Foundation
import Darwin

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

enum Logger {
    
    static func log(_ level: LogLevel,
                    _ message: String,
                    function: StaticString = #function,
                    line: Int = #line) {

        var s = ""
        #if DEBUG
        s += "\(level) - function: \(function), line: \(line) - "
        #endif
        s += message
        s += "\n"
        fputs(s, level.output)
    }
}
