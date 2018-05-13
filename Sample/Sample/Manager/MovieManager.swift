//
//  MovieManager.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

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
    
    // weaver: movieAPI <- APIProtocol
    
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
                print(error)
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
                print(error)
                completion(.failure(.oops))
            }
        }
    }
}
