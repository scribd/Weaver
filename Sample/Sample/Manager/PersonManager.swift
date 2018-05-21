//
//  PersonManager.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - Error

enum PersonManagerError: Error {
    case oops
}

// MARK: - PersonManaging

protocol PersonManaging {
    
    func getPopularPersons(_ completion: @escaping (Result<Page<Person>, PersonManagerError>) -> Void)
}

// MARK: - PersonManager

final class PersonManager: PersonManaging {

    let dependencies: PersonManagerDependencyResolver
    
    // weaver: self.isIsolated = true

    // weaver: logger = Logger
    
    // weaver: movieAPI <- APIProtocol
    
    init(injecting dependencies: PersonManagerDependencyResolver) {
        self.dependencies = dependencies
    }
    
    func getPopularPersons(_ completion: @escaping (Result<Page<Person>, PersonManagerError>) -> Void) {
        
        let request = APIRequest<Page<Person>>(path: "/person/popular")
        
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
}
