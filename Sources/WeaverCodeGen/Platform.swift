//
//  Platform.swift
//  CYaml
//
//  Created by Théophane Rupin on 6/10/20.
//

import Foundation

public enum Platform: String, CaseIterable, Hashable, Codable {
    case OSX
    case macOS
    case iOS
    case watchOS
    case tvOS
}
