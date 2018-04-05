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

    let dependencies = AppDelegateDependencyContainer()
    
    // beaverdi: appDelegate <- AppDelegate
    // beaverdi: appDelegate.customRef = true
    
    // beaverdi: viewController = ViewController
    // beaverdi: viewController.scope = .container
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()
        window?.rootViewController = UINavigationController(rootViewController: dependencies.viewController)
        
        window?.makeKeyAndVisible()
        
        return true
    }
}

extension AppDelegateDependencyContainer {
    
    func appDelegateCustomRef(_: DependencyResolver) -> AppDelegate {
        return UIApplication.shared.delegate! as! AppDelegate
    }
}

