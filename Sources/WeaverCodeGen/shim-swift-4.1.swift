//
//  shim-swift-4.2.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 6/3/18.
//

import Foundation

#if swift(>=4.1)
#else
extension Collection {
    public func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        return try flatMap(transform)
    }
}
#endif
