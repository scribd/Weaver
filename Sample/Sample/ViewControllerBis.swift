//
//  ViewControllerBis.swift
//  Sample
//
//  Created by Théophane Rupin on 4/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import UIKit

class ViewControllerBis: UIViewController {
    
    let dependencies: ViewControllerBisDependencyResolver
    
    // beaverdi: appDelegate <- AppDelegate
    
    init(injecting dependencies: ViewControllerBisDependencyResolver) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .blue
    }
}

