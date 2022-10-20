import XCTest
@testable import Cache

final class MemoryStorageTests: XCTestCase {
    
    private let key = "youknownothing"
    private let testObject = User(firstName: "John", lastName: "Snow")
    private var storage: MemoryStorage<String, User>!
    private let config = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
    
    override func setUp() {
        super.setUp()
        storage = MemoryStorage<String, User>(config: config)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    /// Test that it saves an object
    ///
    func testSetObject() async {
        try? await storage.setObject(testObject, forKey: key, expiry: .never)
        let cachedObject = try! await storage.object(forKey: key)
        XCTAssertNotNil(cachedObject)
        XCTAssertEqual(cachedObject.firstName, testObject.firstName)
        XCTAssertEqual(cachedObject.lastName, testObject.lastName)
    }
    
    func testCacheEntry() async {
        // Returns nil if entry doesn't exist
        var entry = try? await storage.entry(forKey: key)
        XCTAssertNil(entry)
        
        // Returns entry if object exists
        try? await storage.setObject(testObject, forKey: key, expiry: .never)
        entry = try! await storage.entry(forKey: key)
        
        XCTAssertEqual(entry?.object.firstName, testObject.firstName)
        XCTAssertEqual(entry?.object.lastName, testObject.lastName)
        XCTAssertEqual(entry?.expiry.date, config.expiry.date)
    }
    
    func testSetObjectWithExpiry() async {
        let date = Date().addingTimeInterval(1)
        try? await storage.setObject(testObject, forKey: key, expiry: .seconds(1))
        var entry = try! await storage.entry(forKey: key)
        XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
        
        // Timer vs sleep: do not complicate
        sleep(1)
        
        entry = try! await storage.entry(forKey: key)
        XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
    }
    
    /// Test that it removes cached object
    func testRemoveObject() async {
        try? await storage.setObject(testObject, forKey: key, expiry: .never)
        try? await storage.removeObject(forKey: key)
        let cachedObject = try? await storage.object(forKey: key)
        XCTAssertNil(cachedObject)
    }
    
    /// Test that it removes expired object
    ///
    func testRemoveObjectIfExpiredWhenExpired() async {
        let expiry: Expiry = .date(Date().addingTimeInterval(-10))
        try? await storage.setObject(testObject, forKey: key, expiry: expiry)
        try? await storage.removeObjectIfExpired(forKey: key)
        let cachedObject = try? await storage.object(forKey: key)
        
        XCTAssertNil(cachedObject)
    }
    
    /// Test that it doesn't remove not expired object
    ///
    func testRemoveObjectIfExpiredWhenNotExpired() async {
        try? await storage.setObject(testObject, forKey: key, expiry: .never)
        try? await storage.removeObjectIfExpired(forKey: key)
        let cachedObject = try! await storage.object(forKey: key)
        
        XCTAssertNotNil(cachedObject)
    }
    
    /// Test expired object
    ///
    func testExpiredObject() async throws {
        try? await storage.setObject(testObject, forKey: key, expiry: .seconds(1))
        let isExpired = try! await storage.isExpiredObject(forKey: key)
        XCTAssertFalse(isExpired)
        
        sleep(2)
        
        let isExpiredAgain = try! await storage.isExpiredObject(forKey: key)
        XCTAssertTrue(isExpiredAgain)
    }
    
    /// Test that it clears cache directory
    ///
    func testRemoveAll() async {
        try? await storage.setObject(testObject, forKey: key, expiry: .never)
        try? await storage.removeAll()
        let cachedObject = try? await storage.object(forKey: key)
        XCTAssertNil(cachedObject)
    }
    
    /// Test that it removes expired objects
    ///
    func testClearExpired() async {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-10))
        let expiry2: Expiry = .date(Date().addingTimeInterval(10))
        let key1 = "item1"
        let key2 = "item2"
        try? await storage.setObject(testObject, forKey: key1, expiry: expiry1)
        try? await storage.setObject(testObject, forKey: key2, expiry: expiry2)
        try? await storage.removeExpiredObjects()
        let object1 = try? await storage.object(forKey: key1)
        let object2 = try! await storage.object(forKey: key2)
        
        XCTAssertNil(object1)
        XCTAssertNotNil(object2)
    }
    
}
