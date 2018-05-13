//
//  WSMovieViewController+Injectable.swift
//  Sample
//
//  Created by Théophane Rupin on 5/11/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

protocol ObjcInjectable {}

extension WSReviewViewController: ObjcInjectable {
 
    // weaver: movieID <= UInt
    
    // weaver: reviewManager <- ReviewManaging
}
