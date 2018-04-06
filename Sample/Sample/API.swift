//
//  APIClient.swift
//  Sample
//
//  Created by Théophane Rupin on 4/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import BeaverDI

// MARK: - Error

enum APIError: Error {
    case networkingProtocolIsNotHTTP
    case network(Error)
    case url(String)
    case deserialization(Error)
    case api(statusCode: Int, message: String?)
}

// MARK: - HTTP method

enum APIHTTPMethod {
    case get
}

// MARK: - Request

struct APIRequest<Model: Decodable> {
    
    let method: APIHTTPMethod
    let path: String
    var query: [String: Any]
    
    init(method: APIHTTPMethod = .get,
         path: String,
         query: [String: Any] = [:]) {
        self.method = method
        self.path = path
        self.query = query
    }
    
    fileprivate var queryString: String {
        return query.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}

// MARK: - API

protocol APIProtocol {
    
    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void)
}

// MARK: - Movie API

final class MovieAPI: APIProtocol {

    private let dependencies: MovieAPIDependencyResolver
    
    // beaverdi: urlSession <- URLSession
    
    init(injecting dependencies: MovieAPIDependencyResolver) {
        self.dependencies = dependencies
    }

    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) {
        
        let completionOnMainThread = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        var mutableRequest = request
        mutableRequest.query["api_key"] = Constants.apiKey
        
        guard let url = URL(string: Constants.host + request.path + "?" + mutableRequest.queryString) else {
            completion(.failure(.url(request.path)))
            return
        }
        
        let task = dependencies.urlSession.dataTask(with: url) { (data, response, error) in
            
            if let error = error {
                completionOnMainThread(.failure(.network(error)))
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                completionOnMainThread(.failure(.networkingProtocolIsNotHTTP))
                return
            }
            
            guard response.statusCode == 200 || response.statusCode == 304 else {
                completionOnMainThread(.failure(.api(statusCode: response.statusCode, message: nil)))
                return
            }
            
            if let data = data {
                if let errorModel = try? JSONDecoder().decode(APIErrorModel.self, from: data) {
                    completionOnMainThread(.failure(.api(statusCode: errorModel.status_code, message: errorModel.status_message)))
                    return
                }
                
                do {
                    let model = try JSONDecoder().decode(Model.self, from: data)
                    completionOnMainThread(.success(model))
                } catch {
                    completionOnMainThread(.failure(.deserialization(error)))
                }
            }
        }
        
        task.resume()
    }
}

private extension MovieAPI {
    
    enum Constants {
        static let host = "https://api.themoviedb.org/3"
        static let apiKey = "1a6eb1225335bbb37278527537d28a5d"
    }
}
