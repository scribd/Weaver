//
//  HomeViewController.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit
import API

// weaver: import API

final class HomeViewController: UIViewController {
        
    private var movies = [Movie]()
    
    @Weaver(.registration, type: Logger.self)
    private var logger: Logger
    
    @Weaver(.reference)
    private var movieManager: MovieManaging

    @WeaverP2(.registration, type: MovieViewController.self, scope: .weak)
    private var movieController: (UInt, String) -> UIViewController

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MovieTableViewCell.self, forCellReuseIdentifier: "\(MovieTableViewCell.self)")
        return tableView
    }()

    required init(injecting _: HomeViewControllerDependencyResolver) {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        edgesForExtendedLayout = []
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        movieManager.getDiscoverMovies { result in
            switch result {
            case .success(let page):
                self.movies = page.results
                self.tableView.reloadData()
                
            case .failure(let error):
                self.logger.log(.error, "\(error)")
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let movie = movies[indexPath.row]
        let controller = movieController(movie.id, movie.title)
        navigationController?.pushViewController(controller, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
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
