//
//  CacheStorage.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation
import Dispatch

/// Manage storage. Use memory storage if specified.
/// Synchronous by default. Use `async` for asynchronous operations.
///
public final class CacheStorage<Key: Hashable, Value> {
    
    /// Used for sync operations
    private let syncStorage: SyncStorage<Key, Value>
    private let asyncStorage: AsyncStorage<Key, Value>
    private let hybridStorage: HybridStorage<Key, Value>
    
    /// Initialize storage with configuration options.
    ///
    /// - parameters:
    ///   - diskConfig: Configuration for disk storage
    ///   - memoryConfig: Optional. Pass config if you want memory cache
    ///   - transformer: A custom transformer for stored values
    /// - throws: Throw StorageError if any.
    ///
    public convenience init(diskConfig: DiskConfig, memoryConfig: MemoryConfig, transformer: Transformer<Value>) throws {
        let disk = try DiskStorage<Key, Value>(config: diskConfig, transformer: transformer)
        let memory = MemoryStorage<Key, Value>(config: memoryConfig)
        let hybridStorage = HybridStorage(memoryStorage: memory, diskStorage: disk)
        self.init(hybridStorage: hybridStorage)
    }
    
    /// Initialize with sync and async storages
    ///
    /// - parameter syncStorage: Synchronous storage
    /// - parameter asyncStorage: Asynchronous storage
    ///
    public init(hybridStorage: HybridStorage<Key, Value>) {
        self.hybridStorage = hybridStorage
        self.syncStorage = SyncStorage(storage: hybridStorage)
        self.asyncStorage = AsyncStorage(storage: hybridStorage)
    }
    
    /// Used for async operations
    ///
    public lazy var async = self.asyncStorage
    
}

extension CacheStorage: StorageAware {
    
    /// Returns all cached keys
    ///
    public func allKeys() async -> [Key] {
        return await self.syncStorage.allKeys()
    }
    
    /// Returns all cached objects
    ///
    public func allObjects() async -> [Value] {
        return await self.syncStorage.allObjects()
    }
    
    /// Returns the specified entry for the given key
    ///
    /// - parameter key: The key of the cached object.
    /// - returns: An `Entry` object which has metadata, expiry, and an object.
    ///
    public func entry(forKey key: Key) async throws -> Entry<Value> {
        return try await self.syncStorage.entry(forKey: key)
    }
    
    /// Remove an object from the cache.
    ///
    /// - parameter key: The key of the cached object.
    ///
    public func removeObject(forKey key: Key) async throws {
        try await self.syncStorage.removeObject(forKey: key)
    }
    
    /// Add an object to the cache.
    ///
    /// - parameter value: The value of the cached object.
    /// - parameter key: The key of the cached object.
    /// - parameter expiry: A custom expiration for the object.
    ///
    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry?) async throws {
        try await self.syncStorage.setObject(object, forKey: key, expiry: expiry)
    }
    
    /// Removes all cached objects
    ///
    public func removeAll() async throws {
        try await self.syncStorage.removeAll()
    }
    
    /// Removes all expired cache objects
    ///
    public func removeExpiredObjects() async throws {
        try await self.syncStorage.removeExpiredObjects()
    }
    
}

public extension CacheStorage {
    
    func transform<U>(transformer: Transformer<U>) -> CacheStorage<Key, U> {
        return CacheStorage<Key, U>(hybridStorage: hybridStorage.transform(transformer: transformer))
    }
    
}

extension CacheStorage: StorageObservationRegistry {
    
    @discardableResult
    public func addStorageObserver<O: AnyObject>(
        _ observer: O,
        closure: @escaping (O, CacheStorage, StorageChange<Key>) -> Void
    ) -> ObservationToken {
        return hybridStorage.addStorageObserver(observer) { [weak self] observer, _, change in
            guard let strongSelf = self else { return }
            closure(observer, strongSelf, change)
        }
    }
    
    public func removeAllStorageObservers() {
        hybridStorage.removeAllStorageObservers()
    }
    
}

extension CacheStorage: KeyObservationRegistry {
    
    @discardableResult
    public func addObserver<O: AnyObject>(
        _ observer: O,
        forKey key: Key,
        closure: @escaping (O, CacheStorage, KeyChange<Value>) -> Void
    ) -> ObservationToken {
        return hybridStorage.addObserver(observer, forKey: key) { [weak self] observer, _, change in
            guard let strongSelf = self else { return }
            closure(observer, strongSelf, change)
        }
    }
    
    public func removeObserver(forKey key: Key) {
        hybridStorage.removeObserver(forKey: key)
    }
    
    public func removeAllKeyObservers() {
        hybridStorage.removeAllKeyObservers()
    }
    
}

public extension CacheStorage {
    
    /// Returns the total size of the DiskStorage of the underlying HybridStorage in bytes.
    ///
    var totalDiskStorageSize: Int? {
        return self.hybridStorage.diskStorage.totalSize
    }
    
}
