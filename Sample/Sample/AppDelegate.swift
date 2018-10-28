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

    fileprivate let dependencies: AppDelegateDependencyResolver = AppDelegateDependencyContainer()
    
    // weaver: logger = Logger
    // weaver: logger.scope = .container
    
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = { _ in URLSession.shared }
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
    // weaver: movieAPI.builder = AppDelegate.makeMovieAPI

    // weaver: imageManager = ImageManager <- ImageManaging
    // weaver: imageManager.scope = .container
    
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    // weaver: movieManager.builder = AppDelegate.makeMovieManager
    
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
    
    // weaver: reviewManager = ReviewManager <- ReviewManaging
    // weaver: reviewManager.scope = .container
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        
        window = UIWindow()
        
        window?.rootViewController = UINavigationController(rootViewController: dependencies.homeViewController)
        window?.makeKeyAndVisible()
    }
}

extension AppDelegate {

    static func makeMovieAPI(_ dependencies: AppDelegateDependencyResolver) -> APIProtocol {
        return MovieAPI(urlSession: dependencies.urlSession)
    }
    
    static func makeMovieManager(_ dependencies: AppDelegateDependencyResolver) -> MovieManaging {
        return MovieManager(logger: dependencies.logger, host: "https://api.themoviedb.org/3")
    }
}
