//
//  Sequence+Async.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/22.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import Foundation

extension Sequence {
    
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        
        for element in self {
            try await values.append(transform(element))
        }
        
        return values
    }
    
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var values = [T]()
        
        for element in self {
            guard let transformed = try await transform(element) else { continue }
            values.append(transformed)
        }
        
        return values
    }
    
    func asyncForEach(_ operation: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
    
}
