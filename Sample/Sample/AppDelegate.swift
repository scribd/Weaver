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
    
    @Weaver(.registration, type: Logger.self, scope: .container)
    private var logger: Logger
    
    @Weaver(.registration, type: URLSession.self, scope: .container, builder: AppDelegate.makeURLSession)
    private var urlSession: URLSession
    
    @Weaver(.registration, type: MovieAPI.self, scope: .container, builder: AppDelegate.makeMovieAPI)
    private var movieAPI: APIProtocol
    
    @Weaver(.registration, type: ImageManager.self, scope: .container)
    private var imageManager: ImageManaging
    
    @Weaver(.registration, type: MovieManager.self, scope: .container, builder: AppDelegate.makeMovieManager)
    private var movieManager: MovieManaging

    @Weaver(.registration, type: HomeViewController.self, scope: .container)
    @objc private var homeViewController: UIViewController

    // weaver: reviewManager = ReviewManager <- ReviewManaging
    // weaver: reviewManager.scope = .container
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
