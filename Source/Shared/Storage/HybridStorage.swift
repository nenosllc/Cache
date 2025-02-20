//
//  HybridStorage.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation

/// Use both memory and disk storage.
///
/// Tries in memory first.
///
public final class HybridStorage<Key: Hashable, Value> {
    
    public let memoryStorage: MemoryStorage<Key, Value>
    public let diskStorage: DiskStorage<Key, Value>
    
    private(set) var storageObservations = [UUID: (HybridStorage, StorageChange<Key>) -> Void]()
    private(set) var keyObservations = [Key: (HybridStorage, KeyChange<Value>) -> Void]()
    
    public init(memoryStorage: MemoryStorage<Key, Value>, diskStorage: DiskStorage<Key, Value>) {
        self.memoryStorage = memoryStorage
        self.diskStorage = diskStorage
        
        diskStorage.onRemove = { [weak self] path in
            self?.handleRemovedObject(at: path)
        }
    }
    
    private func handleRemovedObject(at path: String) {
        notifyObserver(about: .remove) { key in
            let fileName = diskStorage.makeFileName(for: key)
            return path.contains(fileName)
        }
    }
    
}

extension HybridStorage: StorageAware {
    
    public func allKeys() async -> [Key] {
        return await memoryStorage.allKeys()
    }
    
    public func allObjects() async -> [Value] {
        return await memoryStorage.allObjects()
    }
    
    public func entry(forKey key: Key) async throws -> Entry<Value> {
        do {
            return try await memoryStorage.entry(forKey: key)
        } catch {
            let entry = try await diskStorage.entry(forKey: key)
            // set back to memoryStorage
            try await memoryStorage.setObject(entry.object, forKey: key, expiry: entry.expiry)
            return entry
        }
    }
    
    public func removeObject(forKey key: Key) async throws {
        try await memoryStorage.removeObject(forKey: key)
        try await diskStorage.removeObject(forKey: key)

        notifyStorageObservers(about: .remove(key: key))
    }
    
    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry?) async throws {
        var keyChange: KeyChange<Value>?

        if keyObservations[key] != nil {
            keyChange = await .edit(before: try? self.object(forKey: key), after: object)
        }

        try await memoryStorage.setObject(object, forKey: key, expiry: expiry)
        try await diskStorage.setObject(object, forKey: key, expiry: expiry)

        if let change = keyChange {
            notifyObserver(forKey: key, about: change)
        }

        notifyStorageObservers(about: .add(key: key))
    }
    
    public func removeAll() async throws {
        try await memoryStorage.removeAll()
        try await diskStorage.removeAll()

        notifyStorageObservers(about: .removeAll)
        notifyKeyObservers(about: .remove)
    }
    
    public func removeExpiredObjects() async throws {
        try await memoryStorage.removeExpiredObjects()
        try await diskStorage.removeExpiredObjects()
        
        notifyStorageObservers(about: .removeExpired)
    }
    
}

public extension HybridStorage {
    
    func transform<U>(transformer: Transformer<U>) -> HybridStorage<Key, U> {
        let storage = HybridStorage<Key, U>(
            memoryStorage: memoryStorage.transform(),
            diskStorage: diskStorage.transform(transformer: transformer)
        )
        
        return storage
    }
    
}

extension HybridStorage: StorageObservationRegistry {
    
    @discardableResult
    public func addStorageObserver<O: AnyObject>(
        _ observer: O,
        closure: @escaping (O, HybridStorage, StorageChange<Key>) -> Void
    ) -> ObservationToken {
        let id = UUID()
        
        storageObservations[id] = { [weak self, weak observer] storage, change in
            guard let observer = observer else {
                self?.storageObservations.removeValue(forKey: id)
                return
            }
            
            closure(observer, storage, change)
        }
        
        return ObservationToken { [weak self] in
            self?.storageObservations.removeValue(forKey: id)
        }
    }
    
    public func removeAllStorageObservers() {
        storageObservations.removeAll()
    }
    
    private func notifyStorageObservers(about change: StorageChange<Key>) {
        storageObservations.values.forEach { closure in
            closure(self, change)
        }
    }
    
}

extension HybridStorage: KeyObservationRegistry {
    
    @discardableResult
    public func addObserver<O: AnyObject>(
        _ observer: O,
        forKey key: Key,
        closure: @escaping (O, HybridStorage, KeyChange<Value>) -> Void
    ) -> ObservationToken {
        keyObservations[key] = { [weak self, weak observer] storage, change in
            guard let observer = observer else {
                self?.removeObserver(forKey: key)
                return
            }
            
            closure(observer, storage, change)
        }
        
        return ObservationToken { [weak self] in
            self?.keyObservations.removeValue(forKey: key)
        }
    }
    
    public func removeObserver(forKey key: Key) {
        keyObservations.removeValue(forKey: key)
    }
    
    public func removeAllKeyObservers() {
        keyObservations.removeAll()
    }
    
    private func notifyObserver(forKey key: Key, about change: KeyChange<Value>) {
        keyObservations[key]?(self, change)
    }
    
    private func notifyObserver(about change: KeyChange<Value>, whereKey closure: ((Key) -> Bool)) {
        let observation = keyObservations.first { key, _ in closure(key) }?.value
        observation?(self, change)
    }
    
    private func notifyKeyObservers(about change: KeyChange<Value>) {
        keyObservations.values.forEach { closure in
            closure(self, change)
        }
    }
    
}

public extension HybridStorage {
    
    /// Returns the total size of the underlying ``DiskStorage`` in bytes.
    ///
    var totalDiskStorageSize: Int? {
        return self.diskStorage.totalSize
    }
    
}
