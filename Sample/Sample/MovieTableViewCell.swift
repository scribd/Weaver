//
//  MovieTableViewCell.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit

final class MovieTableViewCell: UITableViewCell {
    
    struct ViewModel {
        let title: String
    }
    
    func bind(_ viewModel: ViewModel) {
        textLabel?.text = viewModel.title
    }
}

extension MovieTableViewCell.ViewModel {
    
    init(_ movie: Movie) {
        self.title = movie.title
    }
}
