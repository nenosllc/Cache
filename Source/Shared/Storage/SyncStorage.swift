//
//  SyncStorage.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation
import Dispatch

/// Manipulate storage in a "all sync" manner.
///
/// Block the current queue until the operation completes.
///
public actor SyncStorage<Key: Hashable, Value> {
    
    public let innerStorage: HybridStorage<Key, Value>
    
    public init(storage: HybridStorage<Key, Value>) {
        self.innerStorage = storage
    }
    
}

extension SyncStorage: StorageAware {
    
    public func allKeys() async -> [Key] {
        return await self.innerStorage.allKeys()
    }
    
    public func allObjects() async -> [Value] {
        return await self.innerStorage.allObjects()
    }
    
    public func entry(forKey key: Key) async throws -> Entry<Value> {
        return try await innerStorage.entry(forKey: key)
    }
    
    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry?) async throws {
        try await innerStorage.setObject(object, forKey: key, expiry: expiry)
    }
    
    public func removeObject(forKey key: Key) async throws {
        try await self.innerStorage.removeObject(forKey: key)
    }
    
    public func removeAll() async throws {
        try await innerStorage.removeAll()
    }
    
    public func removeExpiredObjects() async throws {
        try await innerStorage.removeExpiredObjects()
    }
    
}

public extension SyncStorage {
    
    func transform<U>(transformer: Transformer<U>) -> SyncStorage<Key, U> {
        let storage = SyncStorage<Key, U>(
            storage: innerStorage.transform(transformer: transformer)
        )
        
        return storage
    }
    
}
