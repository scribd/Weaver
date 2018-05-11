//
//  AppDelegate.swift
//  Sample
//
//  Created by Théophane Rupin on 3/27/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import UIKit
import Weaver

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let dependencies = AppDelegateDependencyContainer()
    
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.customRef = true
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container

    // weaver: imageManager = ImageManager <- ImageManaging
    // weaver: imageManager.scope = .container
    
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()

        window?.rootViewController = UINavigationController(rootViewController: dependencies.homeViewController)
        window?.makeKeyAndVisible()
        
        return true
    }
}

extension AppDelegateDependencyContainer {

    func urlSessionCustomRef(_: DependencyContainer) -> URLSession {
        return .shared
    }
}
