//
//  AppDelegate.swift
//  Sample
//
//  Created by Théophane Rupin on 3/27/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import UIKit
import BeaverDI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let dependencies = AppDelegateDependencyContainer()
    
    // beaverdi: urlSession = URLSession
    // beaverdi: urlSession.scope = .container
    // beaverdi: urlSession.customRef = true
    
    // beaverdi: movieAPI = MovieAPI <- APIProtocol
    // beaverdi: movieAPI.scope = .container

    // beaverdi: imageManager = ImageManager <- ImageManaging
    // beaverdi: imageManager.scope = .container
    
    // beaverdi: movieManager = MovieManager <- MovieManaging
    // beaverdi: movieManager.scope = .container
    
    // beaverdi: homeViewController = HomeViewController <- UIViewController
    // beaverdi: homeViewController.scope = .container
    
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

