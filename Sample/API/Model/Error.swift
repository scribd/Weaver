//
//  Error.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public struct APIErrorModel: Decodable {
    public let status_code: Int
    public let status_message: String
}
