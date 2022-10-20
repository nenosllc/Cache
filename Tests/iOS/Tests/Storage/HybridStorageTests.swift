import XCTest
@testable import Cache

final class HybridStorageTests: XCTestCase {
    
    private let cacheName = "WeirdoCache"
    private let key = "alongweirdkey"
    private let testObject = User(firstName: "John", lastName: "Targaryen")
    private var storage: HybridStorage<String, User>!
    private let fileManager = FileManager()
    
    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(config: DiskConfig(name: "HybridDisk"), transformer: TransformerFactory.forCodable(ofType: User.self))
        
        storage = HybridStorage(memoryStorage: memory, diskStorage: disk)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testSetObject() async throws {
        try await storage.setObject(testObject, forKey: key, expiry: .never)
        let cachedObject = try await storage.object(forKey: key)
        XCTAssertEqual(cachedObject, testObject)
        
        let memoryObject = try await storage.memoryStorage.object(forKey: key)
        XCTAssertNotNil(memoryObject)
        
        let diskObject = try await storage.diskStorage.object(forKey: key)
        XCTAssertNotNil(diskObject)
    }
    
    func testEntry() async throws {
        let expiryDate = Date()
        try await storage.setObject(testObject, forKey: key, expiry: .date(expiryDate))
        let entry = try await storage.entry(forKey: key)
        
        XCTAssertEqual(entry.object, testObject)
        XCTAssertEqual(entry.expiry.date, expiryDate)
    }
    
    /// Should resolve from disk and set in-memory cache if object not in-memory.
    ///
    func testObjectCopyToMemory() async throws {
        try await storage.diskStorage.setObject(testObject, forKey: key)
        let cachedObject: User = try await storage.object(forKey: key)
        XCTAssertEqual(cachedObject, testObject)
        
        let inMemoryCachedObject = try await storage.memoryStorage.object(forKey: key)
        XCTAssertEqual(inMemoryCachedObject, testObject)
    }
    
    func testEntityExpiryForObjectCopyToMemory() async throws {
        let date = Date().addingTimeInterval(3)
        try await storage.diskStorage.setObject(testObject, forKey: key, expiry: .seconds(3))
        let entry = try await storage.entry(forKey: key)
        // Accuracy for slow disk processes
        XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 1.0)
        
        let entryAgain = try await storage.memoryStorage.entry(forKey: key)
        // Accuracy for slow disk processes
        XCTAssertEqual(entryAgain.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 1.0)
    }
    
    /// Removes cached object from memory and disk.
    ///
    func testRemoveObject() async throws {
        try await storage.setObject(testObject, forKey: key, expiry: .never)
        let loadedObject = try await storage.object(forKey: key)
        XCTAssertNotNil(loadedObject)
        
        try await storage.removeObject(forKey: key)
        let cachedObject = try? await storage.object(forKey: key)
        XCTAssertNil(cachedObject)
        
        let memoryObject = try? await storage.memoryStorage.object(forKey: key)
        XCTAssertNil(memoryObject)
        
        let diskObject = try? await storage.diskStorage.object(forKey: key)
        XCTAssertNil(diskObject)
    }
    
    /// Clears memory and disk cache.
    ///
    func testClear() async throws {
        try await storage.setObject(testObject, forKey: key, expiry: .never)
        try await storage.removeAll()
        let loadedObject = try? await storage.object(forKey: key)
        XCTAssertNil(loadedObject)
        
        let memoryObject = try? await storage.memoryStorage.object(forKey: key)
        XCTAssertNil(memoryObject)
        
        let diskObject = try? await storage.diskStorage.object(forKey: key)
        XCTAssertNil(diskObject)
    }
    
    func testDiskEmptyAfterClear() async throws {
        try await storage.setObject(testObject, forKey: key, expiry: .never)
        try await storage.removeAll()
        
        let contents = try? fileManager.contentsOfDirectory(atPath: storage.diskStorage.path)
        XCTAssertEqual(contents?.count, 0)
    }
    
    /// Clears expired objects from memory and disk cache.
    ///
    func testClearExpired() async throws {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-10))
        let expiry2: Expiry = .date(Date().addingTimeInterval(10))
        let key1 = "key1"
        let key2 = "key2"
        
        try await storage.setObject(testObject, forKey: key1, expiry: expiry1)
        try await storage.setObject(testObject, forKey: key2, expiry: expiry2)
        
        try await storage.removeExpiredObjects()
        
        let obj1 = try? await storage.object(forKey: key1)
        let obj2 = try? await storage.object(forKey: key2)
        
        XCTAssertNil(obj1)
        XCTAssertNotNil(obj2)
    }
    
    // MARK: - CacheStorage observers
    
    func testAddStorageObserver() async throws {
        var changes = [StorageChange<String>]()
        storage.addStorageObserver(self) { _, _, change in
            changes.append(change)
        }
        
        try await storage.setObject(testObject, forKey: "user1", expiry: .never)
        XCTAssertEqual(changes, [StorageChange.add(key: "user1")])
        XCTAssertEqual(storage.storageObservations.count, 1)
        
        storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(storage.storageObservations.count, 2)
    }
    
    func testRemoveStorageObserver() {
        let token = storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(storage.storageObservations.count, 1)
        
        token.cancel()
        XCTAssertTrue(storage.storageObservations.isEmpty)
    }
    
    func testRemoveAllStorageObservers() {
        storage.addStorageObserver(self) { _, _, _ in }
        storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(storage.storageObservations.count, 2)
        
        storage.removeAllStorageObservers()
        XCTAssertTrue(storage.storageObservations.isEmpty)
    }
    
    // MARK: - Key observers
    
    func testAddObserverForKey() async throws {
        var changes = [KeyChange<User>]()
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }
        
        XCTAssertEqual(storage.keyObservations.count, 1)
        
        try await storage.setObject(testObject, forKey: "user1", expiry: .never)
        XCTAssertEqual(changes, [KeyChange.edit(before: nil, after: testObject)])
        
        storage.addObserver(self, forKey: "user1") { _, _, _ in }
        XCTAssertEqual(storage.keyObservations.count, 1)
        
        storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(storage.keyObservations.count, 2)
    }
    
    func testRemoveKeyObserver() {
        // Test remove for key
        storage.addObserver(self, forKey: "user1") { _, _, _ in }
        XCTAssertEqual(storage.keyObservations.count, 1)
        
        storage.removeObserver(forKey: "user1")
        XCTAssertTrue(storage.storageObservations.isEmpty)
        
        // Test remove by token
        let token = storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(storage.keyObservations.count, 1)
        
        token.cancel()
        XCTAssertTrue(storage.storageObservations.isEmpty)
    }
    
    func testRemoveAllKeyObservers() {
        storage.addObserver(self, forKey: "user1") { _, _, _ in }
        storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(storage.keyObservations.count, 2)
        
        storage.removeAllKeyObservers()
        XCTAssertTrue(storage.keyObservations.isEmpty)
    }
    
}
