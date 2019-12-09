//
//  ReviewManager.swift
//  Sample
//
//  Created by Théophane Rupin on 5/12/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import API

// MARK: - Error

@objc enum ReviewManagerErrorCode: Int {
    case oops = 0
}

@objc final class ReviewManagerError: NSError {
    
    init(_ code: ReviewManagerErrorCode) {
        super.init(domain: "\(ReviewManaging.self)", code: code.rawValue, userInfo: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ReviewManaging

@objc protocol ReviewManaging {
    
    func getReviews(for movieID: UInt, completion: @escaping (ReviewPage?, ReviewManagerError?) -> Void)
}

// MARK: - ReviewManager

final class ReviewManager: ReviewManaging {

    @LoggerDependency(.registration, type: Logger.self)
    private var logger: Logger

    @MovieAPIDependency(.reference)
    private var movieAPI: APIProtocol
    
    required init(injecting _: ReviewManagerDependencyResolver) {
        // no-op
    }
    
    func getReviews(for movieID: UInt, completion: @escaping (ReviewPage?, ReviewManagerError?) -> Void) {

        let request = APIRequest<Page<Review.Properties>>(path: "/movie/\(movieID)/reviews")
        
        movieAPI.send(request: request) { result in
            switch result {
            case .success(let page):
                completion(ReviewPage(page), nil)
            case .failure(let error):
                self.logger.log(.error, "\(error)")
                completion(nil, ReviewManagerError(.oops))
            }
        }
    }
}
