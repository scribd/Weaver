//
//  MovieManager.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import WeaverDI
import API

// MARK: - Error

enum MovieManagerError: Error {
    case oops
}

// MARK: - Manager

protocol MovieManaging {
    
    func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void)
    
    func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void)
}

final class MovieManager: MovieManaging {

    private let dependencies: MovieManagerDependencyResolver
    
    // weaver: logger <- Logger
    
    // weaver: movieAPI = APIProtocol
    // weaver: movieAPI.customRef = true
    
    required init(injecting dependencies: MovieManagerDependencyResolver) {
        self.dependencies = dependencies
    }
    
    func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void) {
        
        let request = APIRequest<Page<Movie>>(path: "/discover/movie")
        
        dependencies.movieAPI.send(request: request) { result in
            switch result {
            case .success(let page):
                completion(.success(page))
            case .failure(let error):
                self.dependencies.logger.log(.error, "\(error)")
                completion(.failure(.oops))
            }
        }
    }
    
    func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void) {
        
        let request = APIRequest<Movie>(path: "/movie/\(id)")
        
        dependencies.movieAPI.send(request: request) { result in
            switch result {
            case .success(let movie):
                completion(.success(movie))
            case .failure(let error):
                self.dependencies.logger.log(.error, "\(error)")
                completion(.failure(.oops))
            }
        }
    }
}

extension MovieManagerDependencyContainer {
    func movieAPICustomRef(_ container: DependencyContainer) -> APIProtocol {
        return MovieAPI(urlSession: container.resolve(URLSession.self, name: "urlSession"))
    }
}
