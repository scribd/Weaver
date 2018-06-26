//
//  Page.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public struct Page<Model: Decodable>: Decodable {
    public let page: UInt
    public let total_results: UInt
    public let total_pages: UInt
    public let results: [Model]
}

