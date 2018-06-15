//
//  Review.swift
//  Sample
//
//  Created by Théophane Rupin on 5/12/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

@objc public final class Review: NSObject {
    
    public struct Properties: Decodable {
        public let id: String
        public let author: String
        public let content: String
        public let url: String
    }
    
    public let properties: Properties
    
    public init(_ properties: Properties) {
        self.properties = properties
    }
}

@objc public final class ReviewPage: NSObject {
    
    public let properties: Page<Review.Properties>
    
    public init(_ properties: Page<Review.Properties>) {
        self.properties = properties
    }
    
    @objc public var page: UInt {
        return properties.page
    }
    
    @objc public var totalResults: UInt {
        return properties.total_results
    }
    
    @objc public var totalPages: UInt {
        return properties.total_pages
    }
    
    @objc public var results: [Review] {
        return properties.results.map { Review($0) }
    }
}
