//
//  Mocks.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit
import XCTest

@testable import Sample

final class APIMock: APIProtocol {
    
    // MARK: - Spies
    
    private(set) var sendDataRequestCallCountSpy = 0

    private(set) var sendModelRequestCallCountSpy = 0

    private(set) var dataRequestConfigSpy: APIRequestConfig?

    private(set) var modelRequestConfigSpy: APIRequestConfig?
    
    // MARK: - Stubs
    
    var sendDataRequestResultStub: Result<Data, APIError> = .failure(.emptyBodyResponse)
    
    var sendModelRequestResultStub: Result<Any, APIError> = .failure(.emptyBodyResponse)
    
    // MARK: - Mocks
    
    func send(request: APIRequest<Data>, completion: @escaping (Result<Data, APIError>) -> Void) {
        sendDataRequestCallCountSpy += 1
        dataRequestConfigSpy = request.config
        completion(sendDataRequestResultStub)
    }
    
    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) where Model: Decodable {
        sendModelRequestCallCountSpy += 1
        modelRequestConfigSpy = request.config
        switch sendModelRequestResultStub {
        case .success(let model):
            completion(.success(model as! Model))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

final class MovieManagerMock: MovieManaging {
    
    // MARK: - Spies
    
    private(set) var getDiscoverMoviesCallCountSpy = 0
    
    private(set) var getMovieCallCountSpy = 0
    
    private(set) var movieIdSpy: UInt?
    
    // MARK: - Stubs
    
    var getDiscoverMoviesResultStub: Result<Page<Movie>, MovieManagerError> = .failure(.oops)
    
    var getMovieResultStub: Result<Movie, MovieManagerError> = .failure(.oops)
    
    // MARK: - Mocks
    
    func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void) {
        getDiscoverMoviesCallCountSpy += 1
        completion(getDiscoverMoviesResultStub)
    }
    
    func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void) {
        getMovieCallCountSpy += 1
        movieIdSpy = id
        completion(getMovieResultStub)
    }
}

final class ImageManagerMock: ImageManaging {
    
    // MARK: - Spies
    
    private(set) var getImageCallCountSpy = 0
    
    private(set) var pathSpy: String?
    
    // MARK: - Stubs
    
    private(set) var getImageResultStub: Result<UIImage, ImageManagerError> = .failure(.oops)
    
    // MARK: - Mocks
    
    func getImage(with path: String, completion: @escaping (Result<UIImage, ImageManagerError>) -> Void) {
        getImageCallCountSpy += 1
        pathSpy = path
        completion(getImageResultStub)
    }
}
