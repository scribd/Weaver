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
    
    fileprivate let dependencies = MainDependencyContainer.appDelegateDependencyResolver()
    
    @LoggerDependency(.registration, type: Logger.self, scope: .container)
    private var logger: Logger
    
    @UrlSessionDependency(.registration, type: URLSession.self, scope: .container, builder: AppDelegate.makeURLSession)
    private var urlSession: URLSession
    
    @MovieAPIDependency(.registration, type: MovieAPI.self, scope: .container, builder: AppDelegate.makeMovieAPI)
    private var movieAPI: APIProtocol
    
    @ImageManagerDependency(.registration, type: ImageManager.self, scope: .container)
    private var imageManager: ImageManaging
    
    @MovieManagerDependency(.registration, type: MovieManager.self, scope: .container, builder: AppDelegate.makeMovieManager)
    private var movieManager: MovieManaging

    @HomeViewControllerDependency(.registration, type: HomeViewController.self, scope: .container)
    private var homeViewController: UIViewController

    @ReviewManagerDependency(.registration, type: ReviewManager.self, scope: .container, objc: true)
    private var reviewManager: ReviewManaging
    
    func applicationDidFinishLaunching(_ application: UIApplication) {

        window = UIWindow()
        
        window?.rootViewController = UINavigationController(rootViewController: dependencies.homeViewController)
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
