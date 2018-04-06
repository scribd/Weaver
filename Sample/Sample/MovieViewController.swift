//
//  MovieViewController.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit

final class MovieViewController: UIViewController {
    
    private let dependencies: MovieViewControllerDependencyResolver

    /// beaverdi: movieID <= UInt

    // beaverdi: movieManager <- MovieManaging

    required init(injecting dependencies: MovieViewControllerDependencyResolver) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .red
    }
}
