//
//  GeneratorTests.swift
//  BeaverDICodeGenTests
//
//  Created by Théophane Rupin on 3/4/18.
//

import Foundation
import XCTest

@testable import BeaverDICodeGen

final class GeneratorTests: XCTestCase {
    
    func testGenerator() {
        
        do {
            let input = DataInputMock()
            let data = ResolverData(targetTypeName: "Test", parentTypeName: "ParentTest", dependencies: [])

            let generator = Generator(template: "dependency_resolver")
            try generator.generate(in: input, resolver: data)
            
            XCTAssertEqual(input.string!, """
final class TestDependencies: DependencyResolver {
  init(_ parent: MainDependencyResolver) {
    super.init(parent)
  }

  override func registerDependencies(in store: DependencyStore) {
    store.register(APIProtocol.self, scope: .graph, builder: { _ in
      return API()
    })

    store.register(RouterProtocol.self, scope: .container, builder: { dependencies in
      return Router(dependencies)
    })

    store.register(SessionProtocol.self, scope: .weak, builder: { dependencies in
      return Session(dependencies)
    })
  }
}

extension MyService {
  var api: APIProtocol {
    return dependencies.resolve(APIProtocol.self)
  }

  var router: RouterProtocol {
    return dependencies.resolve(RouterProtocol.self)
  }

  var session: SessionProtocol? {
    return dependencies.resolve(Optional<SessionProtocol>.self)
  }

  var otherService: MyOtherServiceProtocol {
    return dependencies.resolve(MyOtherServiceProtocol.self)
  }
}
""")
            
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        
    }
}
