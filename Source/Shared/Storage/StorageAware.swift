//
//  StorageAware.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation

/// A protocol used for saving and loading from storage.
///
public protocol StorageAware {
    
    associatedtype Key: Hashable
    associatedtype Value
    
    /// Get all keys in the storage
    ///
    func allKeys() async -> [Key]
    
    /// Get all objects from the storage
    ///
    func allObjects() async -> [Value]
    
    /// Tries to retrieve the object from the storage.
    ///
    /// - parameter key: Unique key to identify the object in the cache
    /// - returns: Cached object or nil if not found
    ///
    func object(forKey key: Key) async throws -> Value
    
    /// Get cache entry which includes object with metadata.
    ///
    /// - parameter key: Unique key to identify the object in the cache
    /// - returns: Object wrapper with metadata or nil if not found
    ///
    func entry(forKey key: Key) async throws -> Entry<Value>
    
    /// Removes the object by the given key.
    ///
    /// - parameter key: Unique key to identify the object.
    ///
    func removeObject(forKey key: Key) async throws
    
    /// Saves passed object.
    ///
    /// - parameter key: Unique key to identify the object in the cache.
    /// - parameter object: Object that needs to be cached.
    /// - parameter expiry: Overwrite expiry for this object only.
    ///
    func setObject(_ object: Value, forKey key: Key, expiry: Expiry?) async throws
    
    /// Check if an object exist by the given key.
    ///
    /// - parameter key: Unique key to identify the object.
    ///
    func objectExists(forKey key: Key) async -> Bool
    
    /// Removes all objects from the cache storage.
    ///
    func removeAll() async throws
    
    /// Clears all expired objects.
    ///
    func removeExpiredObjects() async throws
    
    /// Check if an expired object by the given key.
    ///
    /// - parameter key: Unique key to identify the object.
    ///
    func isExpiredObject(forKey key: Key) async throws -> Bool
    
}

public extension StorageAware {
    
    func object(forKey key: Key) async throws -> Value {
        return try await entry(forKey: key).object
    }
    
    func objectExists(forKey key: Key) async -> Bool {
        do {
            let _: Value = try await object(forKey: key)
            return true
        } catch {
            return false
        }
    }
    
    func isExpiredObject(forKey key: Key) async throws -> Bool {
        do {
            let entry = try await self.entry(forKey: key)
            return entry.expiry.isExpired
        } catch {
            return true
        }
    }
    
}
