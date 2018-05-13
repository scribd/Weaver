//
//  Movie.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

struct APIErrorModel: Decodable {
    let status_code: Int
    let status_message: String
}

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

struct Page<Model: Decodable>: Decodable {
    let page: UInt
    let total_results: UInt
    let total_pages: UInt
    let results: [Model]
}

