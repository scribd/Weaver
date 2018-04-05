//
//  HomeViewController.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit

final class HomeViewController: UIViewController {
    
    private let dependencies: HomeViewControllerDependencyResolver
    
    private var movies = [Movie]()
    
    // beaverdi: movieManager <- MovieManaging
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MovieTableViewCell.self, forCellReuseIdentifier: "\(MovieTableViewCell.self)")
        return tableView
    }()

    required init(injecting dependencies: HomeViewControllerDependencyResolver) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        dependencies.movieManager.getDiscoverMovies { result in
            switch result {
            case .success(let page):
                self.movies = page.results
                
            case .failure(let error):
                print(error)
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    
}

extension HomeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(MovieTableViewCell.self)", for: indexPath) as? MovieTableViewCell else {
            fatalError("Inconsitent data source")
        }

        let movie = movies[indexPath.row]
        let viewModel = MovieTableViewCell.ViewModel(movie)
        cell.bind(viewModel)
        
        return cell
    }
}
