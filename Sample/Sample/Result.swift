//
//  Result.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

enum Result<Value, Error: Swift.Error> {
    case success(Value)
    case failure(Error)
}
