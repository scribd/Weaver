//
//  Movie.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public struct Movie: Decodable {
    public let vote_count: UInt
    public let id: UInt
    public let video: Bool
    public let vote_average: Float
    public let title: String
    public let popularity: Float
    public let poster_path: String
    public let original_language: String
    public let original_title: String
    public let adult: Bool
    public let overview: String
    public let release_date: String
}
