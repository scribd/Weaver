//
//  Person.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public struct Person: Decodable {
    public let id: String
    public let name: String
    public let popularity: Double
    public let profile_path: String
}
