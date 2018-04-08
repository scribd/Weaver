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
    
    struct ViewModel {
        let thumbnail: String
    }
    
    private let dependencies: MovieViewControllerDependencyResolver

    // beaverdi: movieID <= UInt
    // beaverdi: title <= String

    // beaverdi: movieManager <- MovieManaging
    
    // beaverdi: imageManager <- ImageManaging
    
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    required init(injecting dependencies: MovieViewControllerDependencyResolver) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = dependencies.title
        view.backgroundColor = .black
        edgesForExtendedLayout = []

        view.addSubview(thumbnailImageView)
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        thumbnailImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        loadData { viewModel in
            self.dependencies.imageManager.getImage(with: viewModel.thumbnail) { result in
                switch result {
                case .success(let image):
                    self.thumbnailImageView.image = image
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    private func loadData(completion: @escaping (ViewModel) -> ()) {
        dependencies.movieManager.getMovie(id: dependencies.movieID) { result in
            switch result {
            case .success(let movie):
                completion(ViewModel(movie))
            case .failure(let error):
                print(error)
                completion(ViewModel())
            }
        }
    }
}

private extension MovieViewController.ViewModel {
    
    init() {
        thumbnail = ""
    }
    
    init(_ movie: Movie) {
        thumbnail = movie.poster_path
    }
}
