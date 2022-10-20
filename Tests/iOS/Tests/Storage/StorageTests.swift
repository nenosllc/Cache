import XCTest
@testable import Cache

final class StorageTests: XCTestCase {
    
    private var storage: CacheStorage<String, User>!
    let user = User(firstName: "John", lastName: "Snow")
    
    override func setUp() {
        super.setUp()
        
        storage = try! CacheStorage<String, User>(
            diskConfig: DiskConfig(name: "Thor"),
            memoryConfig: MemoryConfig(),
            transformer: TransformerFactory.forCodable(ofType: User.self)
        )
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testSync() async throws {
        try await storage.setObject(user, forKey: "user", expiry: .never)
        let cachedObject = try await storage.object(forKey: "user")
        
        XCTAssertEqual(cachedObject, user)
    }
    
    func testAsync() async {
        try? await storage.async.setObject(user, forKey: "user", expiry: nil)
        let loadedObject = try? await storage.async.object(forKey: "user")
        
        if loadedObject == nil {
            XCTFail()
        }
        
        XCTAssertEqual(loadedObject, self.user)
    }
    
    func testMigration() async {
        struct Person1: Codable {
            let fullName: String
        }
        
        struct Person2: Codable {
            let firstName: String
            let lastName: String
        }
        
        let person1Storage = storage.transformCodable(ofType: Person1.self)
        let person2Storage = storage.transformCodable(ofType: Person2.self)
        
        // Firstly, save object of type Person1
        let person = Person1(fullName: "John Snow")
        
        try! await person1Storage.setObject(person, forKey: "person", expiry: .never)
        let loadedPerson2Object = try? await person2Storage.object(forKey: "person")
        XCTAssertNil(loadedPerson2Object)
        
        // Later, convert to Person2, do the migration, then overwrite
        let tempPerson = try! await person1Storage.object(forKey: "person")
        let parts = tempPerson.fullName.split(separator: " ")
        let migratedPerson = Person2(firstName: String(parts[0]), lastName: String(parts[1]))
        try! await person2Storage.setObject(migratedPerson, forKey: "person", expiry: .never)
        
        let loadedPerson2Name = try? await person2Storage.object(forKey: "person").firstName
        XCTAssertEqual(loadedPerson2Name, "John")
    }
    
    func testSameProperties() async {
        struct Person: Codable {
            let firstName: String
            let lastName: String
        }
        
        struct Alien: Codable {
            let firstName: String
            let lastName: String
        }
        
        let personStorage = storage.transformCodable(ofType: Person.self)
        let alienStorage = storage.transformCodable(ofType: Alien.self)
        
        let person = Person(firstName: "John", lastName: "Snow")
        try! await personStorage.setObject(person, forKey: "person", expiry: .never)
        
        // As long as it has same properties, it works too
        let cachedObject = try! await alienStorage.object(forKey: "person")
        XCTAssertEqual(cachedObject.firstName, "John")
    }
    
    // MARK: - CacheStorage observers
    
    func testAddStorageObserver() async throws {
        var changes = [StorageChange<String>]()
        var observer: ObserverMock? = ObserverMock()
        
        storage.addStorageObserver(observer!) { _, _, change in
            changes.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        try await storage.setObject(user, forKey: "user2", expiry: .never)
        try await storage.removeObject(forKey: "user1")
        try await storage.removeExpiredObjects()
        try await storage.removeAll()
        observer = nil
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        
        let expectedChanges: [StorageChange<String>] = [
            .add(key: "user1"),
            .add(key: "user2"),
            .remove(key: "user1"),
            .removeExpired,
            .removeAll
        ]
        
        XCTAssertEqual(changes, expectedChanges)
    }
    
    func testRemoveAllStorageObservers() async throws {
        var changes1 = [StorageChange<String>]()
        var changes2 = [StorageChange<String>]()
        
        storage.addStorageObserver(self) { _, _, change in
            changes1.append(change)
        }
        
        storage.addStorageObserver(self) { _, _, change in
            changes2.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertEqual(changes1, [StorageChange.add(key: "user1")])
        XCTAssertEqual(changes2, [StorageChange.add(key: "user1")])
        
        changes1.removeAll()
        changes2.removeAll()
        storage.removeAllStorageObservers()
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertTrue(changes1.isEmpty)
        XCTAssertTrue(changes2.isEmpty)
    }
    
    // MARK: - Key observers
    
    func testAddObserverForKey() async throws {
        var changes = [KeyChange<User>]()
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }
        
        storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertEqual(changes, [KeyChange.edit(before: nil, after: user)])
    }
    
    func testKeyObserverWithRemoveExpired() async throws {
        var changes = [KeyChange<User>]()
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }
        
        storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: Expiry.seconds(-1000))
        try await storage.removeExpiredObjects()
        
        XCTAssertEqual(changes, [.edit(before: nil, after: user), .remove])
    }
    
    func testKeyObserverWithRemoveAll() async throws {
        var changes1 = [KeyChange<User>]()
        var changes2 = [KeyChange<User>]()
        
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes1.append(change)
        }
        
        storage.addObserver(self, forKey: "user2") { _, _, change in
            changes2.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        try await storage.setObject(user, forKey: "user2", expiry: .never)
        try await storage.removeAll()
        
        XCTAssertEqual(changes1, [.edit(before: nil, after: user), .remove])
        XCTAssertEqual(changes2, [.edit(before: nil, after: user), .remove])
    }
    
    func testRemoveKeyObserver() async throws {
        var changes = [KeyChange<User>]()
        
        // Test remove
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }
        
        storage.removeObserver(forKey: "user1")
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertTrue(changes.isEmpty)
        
        // Test remove by token
        let token = storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }
        
        token.cancel()
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertTrue(changes.isEmpty)
    }
    
    func testRemoveAllKeyObservers() async throws {
        var changes1 = [KeyChange<User>]()
        var changes2 = [KeyChange<User>]()
        
        storage.addObserver(self, forKey: "user1") { _, _, change in
            changes1.append(change)
        }
        
        storage.addObserver(self, forKey: "user2") { _, _, change in
            changes2.append(change)
        }
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        try await storage.setObject(user, forKey: "user2", expiry: .never)
        XCTAssertEqual(changes1, [KeyChange.edit(before: nil, after: user)])
        XCTAssertEqual(changes2, [KeyChange.edit(before: nil, after: user)])
        
        changes1.removeAll()
        changes2.removeAll()
        storage.removeAllKeyObservers()
        
        try await storage.setObject(user, forKey: "user1", expiry: .never)
        XCTAssertTrue(changes1.isEmpty)
        XCTAssertTrue(changes2.isEmpty)
    }
    
}

private class ObserverMock {
    
}
