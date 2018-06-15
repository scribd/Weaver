//
//  MovieManagerTests.swift
//  SampleTests
//
//  Created by Théophane Rupin on 4/9/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import API

final class MovieManagerTests: XCTestCase {
    
    var movieManagerDependencyResolverSpy: MovieManagerDependencyResolverSpy!
    var movieManager: MovieManager!
    
    var movie: Movie {
        return Movie(vote_count: 1, id: 42, video: false, vote_average: 0, title: "test",
                     popularity: 2, poster_path: "test", original_language: "en",
                     original_title: "test", adult: false,
                     overview: "test", release_date: "01-01-2001")
    }
    
    override func setUp() {
        super.setUp()
        
        movieManagerDependencyResolverSpy = MovieManagerDependencyResolverSpy()
        movieManager = MovieManager(injecting: movieManagerDependencyResolverSpy)
    }
    
    override func tearDown() {
        defer { super.tearDown() }
        
        movieManagerDependencyResolverSpy = nil
        movieManager = nil
    }
    
    func test_movieManager_getDiscoverMovies_should_retrieve_an_array_of_movies() {

        let page = Page(page: 2, total_results: 2, total_pages: 10, results: [movie, movie])
        
        let movieAPISpy = movieManagerDependencyResolverSpy.movieAPISpy
        movieAPISpy.sendModelRequestResultStub = .success(page)
        
        let expectation = self.expectation(description: "get_movies")
        movieManager.getDiscoverMovies { result in
            switch result {
            case .success(let page):
                XCTAssertEqual(page.results.count, 2)
                XCTAssertEqual(movieAPISpy.modelRequestConfigRecord.first?.path, "/discover/movie")
                XCTAssertEqual(movieAPISpy.modelRequestConfigRecord.count, 1)
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1)
    }
    
    func test_movieManager_getMovie_should_retriave_a_movie() {
        
        let movieAPISpy = movieManagerDependencyResolverSpy.movieAPISpy
        movieAPISpy.sendModelRequestResultStub = .success(movie)
        
        let expectation = self.expectation(description: "get_movie")
        movieManager.getMovie(id: 42) { result in
            switch result {
            case .success(let movie):
                XCTAssertEqual(movie.id, 42)
                XCTAssertEqual(movieAPISpy.modelRequestConfigRecord.first?.path, "/movie/42")
                XCTAssertEqual(movieAPISpy.modelRequestConfigRecord.count, 1)
                
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1)
    }
}
