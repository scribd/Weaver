//
//  Reference.swift
//  WeaverDI
//
//  Created by Théophane Rupin on 7/17/18.
//

import Foundation

public final class Reference<T: AnyObject> {
    
    public enum ReferenceType {
        case strong
        case weak
    }
    
    private weak var weakValue: T?
    private let strongValue: T?
    
    public init(_ value: T, type: ReferenceType = .strong) {
        switch type {
        case .strong:
            strongValue = value
            weakValue = nil
        case .weak:
            weakValue = value
            strongValue = nil
        }
    }
    
    var value: T? {
        return weakValue ?? strongValue ?? nil
    }
}
