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

    // weaver: self.isIsolated = true
    
    // weaver: movieAPI <- APIProtocol
    
    func getPopularPersons(_ completion: @escaping (Result<Page<Person>, PersonManagerError>) -> Void) {
        
    }
}
