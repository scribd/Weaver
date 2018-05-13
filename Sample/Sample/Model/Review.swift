//
//  Review.swift
//  Sample
//
//  Created by Théophane Rupin on 5/12/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

@objc final class Review: NSObject {
    
    struct Properties: Decodable {
        let id: String
        let author: String
        let content: String
        let url: String
    }
    
    let properties: Properties
    
    init(_ properties: Properties) {
        self.properties = properties
    }
}

@objc final class ReviewPage: NSObject {
    
    let properties: Page<Review.Properties>
    
    init(_ properties: Page<Review.Properties>) {
        self.properties = properties
    }
    
    @objc var page: UInt {
        return properties.page
    }
    
    @objc var totalResults: UInt {
        return properties.total_results
    }
    
    @objc var totalPages: UInt {
        return properties.total_pages
    }
    
    @objc var results: [Review] {
        return properties.results.map { Review($0) }
    }
}
