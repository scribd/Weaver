//
//  Mocks.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 3/4/18.
//

import Foundation

@testable import BeaverDICodeGen

final class DataInputMock: DataInput {
    
    var string: String?
    
    static func +=(fileInput: DataInputMock, string: String) {
        fileInput.string = (fileInput.string ?? "") + string
    }
}
