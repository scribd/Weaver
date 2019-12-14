//
//  PersonManager.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import API

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

    // weaver: self.isIsolated = true

    @Weaver(.registration, type: Logger.self)
    private var logger: Logger

    @Weaver(.reference)
    private var movieAPI: APIProtocol
    
    init(injecting _: PersonManagerDependencyResolver) {
        // no-op
    }
    
    func getPopularPersons(_ completion: @escaping (Result<Page<Person>, PersonManagerError>) -> Void) {
        
        let request = APIRequest<Page<Person>>(path: "/person/popular")
        
        movieAPI.send(request: request) { result in
            switch result {
            case .success(let page):
                completion(.success(page))

            case .failure(let error):
                self.logger.log(.error, "\(error)")
                completion(.failure(.oops))
            }
        }
    }
}
