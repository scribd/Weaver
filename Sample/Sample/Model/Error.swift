//
//  Error.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

struct APIErrorModel: Decodable {
    let status_code: Int
    let status_message: String
}
