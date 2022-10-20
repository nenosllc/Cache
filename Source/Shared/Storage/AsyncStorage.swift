//
//  AsyncStorage.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation
import Dispatch

/// Manipulate storage in a "all async" manner.
///
public actor AsyncStorage<Key: Hashable, Value> {
    
    public let innerStorage: HybridStorage<Key, Value>
    
    public init(storage: HybridStorage<Key, Value>) {
        self.innerStorage = storage
    }
}

extension AsyncStorage: StorageAware {
    
    public func allKeys() async -> [Key] {
        return await self.innerStorage.allKeys()
    }
    
    public func allObjects() async -> [Value] {
        return await self.innerStorage.allObjects()
    }
    
    public func entry(forKey key: Key) async throws -> Entry<Value> {
        return try await self.innerStorage.entry(forKey: key)
    }
    
    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry? = nil) async throws {
        try await self.innerStorage.setObject(object, forKey: key, expiry: expiry)
    }
    
    public func removeObject(forKey key: Key) async throws {
        return try await self.innerStorage.removeObject(forKey: key)
    }
    
    public func removeAll() async throws {
        try await self.innerStorage.removeAll()
    }
    
    public func removeExpiredObjects() async throws {
        try await self.innerStorage.removeExpiredObjects()
    }
    
    public func object(forKey key: Key) async throws -> Value {
        return try await self.entry(forKey: key).object
    }
    
    public func objectExists(forKey key: Key) async -> Bool {
        do {
            _ = try await self.object(forKey: key)
            return true
        } catch {
            return false
        }
    }
    
}

public extension AsyncStorage {
    
    func transform<U>(transformer: Transformer<U>) -> AsyncStorage<Key, U> {
        let storage = AsyncStorage<Key, U>(
            storage: innerStorage.transform(transformer: transformer)
        )
        
        return storage
    }
    
}
