//
//  ImageManagerTests.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Sample

final class ImageManagerTests: XCTestCase {
    
    var imageManagerDependencyResolverMock: ImageManagerDependencyResolverMock!
    var imageManager: ImageManager!
    
    override func setUp() {
        super.setUp()
        
        imageManagerDependencyResolverMock = ImageManagerDependencyResolverMock()
        imageManager = ImageManager(injecting: imageManagerDependencyResolverMock)
    }
    
    override func tearDown() {
        defer { super.tearDown() }
        
        imageManagerDependencyResolverMock = nil
        imageManager = nil
    }
    
    func test_getImage_should_retrive_an_image() {
        
        let imageData = UIImagePNGRepresentation(.from(color: .black))!

        let movieAPIMock = imageManagerDependencyResolverMock.movieAPIMock
        movieAPIMock.sendDataRequestResultStub = .success(imageData)
        
        let expectation = self.expectation(description: "get_image")
        imageManager.getImage(with: "image") { result in
            switch result {
            case .success(let image):
                XCTAssertEqual(UIImagePNGRepresentation(image), imageData)
                XCTAssertEqual(movieAPIMock.dataRequestConfigSpy.first?.path, "image")
                XCTAssertEqual(movieAPIMock.dataRequestConfigSpy.count, 1)
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1)
    }
}

// MARK: - Utils

private extension UIImage {

    static func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}
