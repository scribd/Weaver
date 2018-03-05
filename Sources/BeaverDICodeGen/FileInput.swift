//
//  FileInput.swift
//  BeaverDICodeGen
//
//  Created by Théophane Rupin on 3/2/18.
//

import Foundation

public protocol DataInput {
    static func += (_ fileInput: Self, _ string: String)
}

