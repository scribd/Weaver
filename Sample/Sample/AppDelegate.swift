//
//  AppDelegate.swift
//  Sample
//
//  Created by Théophane Rupin on 3/27/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import UIKit
import API

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    private let dependencies = MainDependencyContainer.appDelegateDependencyResolver()
    
    @Weaver(.registration)
    private var logger: Logger
    
    @Weaver(.registration, builder: AppDelegate.makeURLSession)
    private var urlSession: URLSession
    
    @Weaver(.registration, type: MovieAPI.self, builder: AppDelegate.makeMovieAPI)
    private var movieAPI: APIProtocol
    
    @Weaver(.registration, type: ImageManager.self)
    private var imageManager: ImageManaging
    
    @Weaver(.registration, type: MovieManager.self, builder: AppDelegate.makeMovieManager)
    private var movieManager: MovieManaging

    @Weaver(.registration, type: HomeViewController.self)
    @objc private var homeViewController: UIViewController

    // weaver: reviewManager = ReviewManager <- ReviewManaging
    // weaver: reviewManager.objc = true
    
    func applicationDidFinishLaunching(_ application: UIApplication) {

        window = UIWindow()
        
        window?.rootViewController = UINavigationController(rootViewController: homeViewController)
        window?.makeKeyAndVisible()
    }
}

extension AppDelegate {
    
    static func makeURLSession(_ dependencies: URLSessionInputDependencyResolver) -> URLSession {
        return .shared
    }

    static func makeMovieAPI(_ dependencies: MovieAPIInputDependencyResolver) -> APIProtocol {
        return MovieAPI(urlSession: dependencies.urlSession)
    }
    
    static func makeMovieManager(_ dependencies: MovieManagerInputDependencyResolver) -> MovieManaging {
        return MovieManager(host: "https://api.themoviedb.org/3", logger: dependencies.logger)
    }
}
