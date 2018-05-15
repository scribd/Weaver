//
//  Person.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

struct Person: Decodable {
    let id: String
    let name: String
    let popularity: Double
    let profile_path: String
}
