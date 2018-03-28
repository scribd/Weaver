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

    // beaverdi: appDelegate <- UIApplicationDelegate
    // beaverdi: appDelegate.custom = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()
        window?.rootViewController = ViewController.makeViewController()
        
        window?.makeKeyAndVisible()
        
        return true
    }
}

extension AppDelegateDependencyContainer {
    
    var appDelegate: UIApplicationDelegate {
        return UIApplication.shared.delegate!
    }
}

