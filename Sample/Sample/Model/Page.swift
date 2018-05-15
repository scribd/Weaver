//
//  Page.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

struct Page<Model: Decodable>: Decodable {
    let page: UInt
    let total_results: UInt
    let total_pages: UInt
    let results: [Model]
}

