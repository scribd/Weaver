//
//  Spies.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit
import XCTest

@testable import API

final class APISpy: APIProtocol {
    
    // MARK: - Spies
    
    private(set) var dataRequestConfigRecord = [APIRequestConfig]()

    private(set) var modelRequestConfigRecord = [APIRequestConfig]()
    
    // MARK: - Stubs
    
    var sendDataRequestResultStub: Result<Data, APIError> = .failure(.emptyBodyResponse)
    
    var sendModelRequestResultStub: Result<Any, APIError> = .failure(.emptyBodyResponse)
    
    // MARK: - Implementation
    
    func send(request: APIRequest<Data>, completion: @escaping (Result<Data, APIError>) -> Void) {
        dataRequestConfigRecord.append(request.config)
        completion(sendDataRequestResultStub)
    }
    
    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) where Model: Decodable {
        modelRequestConfigRecord.append(request.config)

        switch sendModelRequestResultStub {
        case .success(let model):
            completion(.success(model as! Model))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

final class MovieManagerSpy: MovieManaging {
    
    // MARK: - Spies
    
    private(set) var getDiscoverMoviesCallCountRecord = 0
    
    private(set) var movieIdRecord = [UInt]()
    
    // MARK: - Stubs
    
    var getDiscoverMoviesResultStub: Result<Page<Movie>, MovieManagerError> = .failure(.oops)
    
    var getMovieResultStub: Result<Movie, MovieManagerError> = .failure(.oops)
    
    // MARK: - Implementation
    
    func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void) {
        getDiscoverMoviesCallCountRecord += 1
        completion(getDiscoverMoviesResultStub)
    }
    
    func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void) {
        movieIdRecord.append(id)
        completion(getMovieResultStub)
    }
}

final class ImageManagerSpy: ImageManaging {
    
    // MARK: - Spies
    
    private(set) var pathRecord = [String]()
    
    // MARK: - Stubs
    
    private(set) var getImageResultStub: Result<UIImage, ImageManagerError> = .failure(.oops)
    
    // MARK: - Implementation
    
    func getImage(with path: String, completion: @escaping (Result<UIImage, ImageManagerError>) -> Void) {
        pathRecord.append(path)
        completion(getImageResultStub)
    }
}
