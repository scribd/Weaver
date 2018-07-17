//
//  AppDelegate.swift
//  Sample
//
//  Created by Théophane Rupin on 3/27/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import UIKit
import WeaverDI
import API

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let dependencies = AppDelegateDependencyContainer()
    
    // weaver: logger = Logger
    // weaver: logger.scope = .container
    
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.customRef = true
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
    // weaver: movieAPI.customRef = true

    // weaver: imageManager = ImageManager <- ImageManaging
    // weaver: imageManager.scope = .container
    // weaver: imageManager.customRef = true
    
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    // weaver: movieManager.customRef = true
    
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
    
    // weaver: reviewManager = ReviewManager <- ReviewManaging
    // weaver: reviewManager.scope = .container
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()

        window?.rootViewController = UINavigationController(rootViewController: dependencies.homeViewController)
        window?.makeKeyAndVisible()
        
        return true
    }
}

extension AppDelegateDependencyResolver {

    func urlSessionCustomRef() -> URLSession {
        return .shared
    }
    
    func movieAPICustomRef() -> APIProtocol {
        let configuration = URLSessionConfiguration.default
        assert(configuration.urlCache != nil, "\(AppDelegateDependencyResolver.self): urlCache should not be nil.")
        configuration.urlCache?.diskCapacity = 1024 * 1024 * 50
        configuration.urlCache?.memoryCapacity = 1024 * 1024 * 5
        let urlSession = URLSession(configuration: configuration)
        return MovieAPI(urlSession: urlSession)
    }
    
    func imageManagerCustomRef() -> ImageManaging {
        return ImageManager(movieAPI: movieAPI)
    }
    
    func movieManagerCustomRef() -> MovieManaging {
        return MovieManager(logger: logger, host: "https://api.themoviedb.org/3")
    }
}
