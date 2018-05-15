//
//  Movie.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

struct Movie: Decodable {
    let vote_count: UInt
    let id: UInt
    let video: Bool
    let vote_average: Float
    let title: String
    let popularity: Float
    let poster_path: String
    let original_language: String
    let original_title: String
    let backdrop_path: String
    let adult: Bool
    let overview: String
    let release_date: String
}
