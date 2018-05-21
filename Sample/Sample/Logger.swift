//
//  Logger.swift
//  Sample
//
//  Created by Théophane Rupin on 5/20/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

enum LogLevel: String {
    case error = "ERROR"
    case warning = "WARNING"
    case debug = "DEBUG"
    case info = "INFO"
}

final class Logger {
    
    func log(_ level: LogLevel,
             _ message: String,
             file: StringLiteralType = #file,
             function: StringLiteralType = #function,
             line: Int = #line) {
        
        print("[\(level.rawValue)] [\(file):\(function):\(line)] - \(message)")
    }
}
