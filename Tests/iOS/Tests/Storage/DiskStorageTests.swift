import XCTest
@testable import Cache

final class DiskStorageTests: XCTestCase {
    
    private let key = "youknownothing"
    private let testObject = User(firstName: "John", lastName: "Snow")
    private let fileManager = FileManager()
    private var storage: DiskStorage<String, User>!
    private let config = DiskConfig(name: "Floppy")
    
    override func setUp() {
        super.setUp()
        storage = try! DiskStorage<String, User>(config: config, transformer: TransformerFactory.forCodable(ofType: User.self))
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testInit() {
        // Test that it creates cache directory
        let fileExist = fileManager.fileExists(atPath: storage.path)
        XCTAssertTrue(fileExist)
        
        // Test that it returns the default maximum size of a cache
        XCTAssertEqual(config.maxSize, 0)
    }
    
    /// Test that it returns the correct path
    func testDefaultPath() {
        let paths = NSSearchPathForDirectoriesInDomains(
            .cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true
        )
        let path = "\(paths.first!)/\(config.name.capitalized)"
        XCTAssertEqual(storage.path, path)
    }
    
    /// Test that it returns the correct path
    func testCustomPath() throws {
        let url = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let customConfig = DiskConfig(name: "SSD", directory: url)
        
        storage = try DiskStorage<String, User>(config: customConfig, transformer: TransformerFactory.forCodable(ofType: User.self))
        
        XCTAssertEqual(
            storage.path,
            url.appendingPathComponent("SSD", isDirectory: true).path
        )
    }
    
    /// Test that it sets attributes
    func testSetDirectoryAttributes() async throws {
        try await storage.setObject(testObject, forKey: key)
        try storage.setDirectoryAttributes([FileAttributeKey.immutable: true])
        let attributes = try fileManager.attributesOfItem(atPath: storage.path)
        
        XCTAssertTrue(attributes[FileAttributeKey.immutable] as? Bool == true)
        try storage.setDirectoryAttributes([FileAttributeKey.immutable: false])
    }
    
    /// Test that it saves an object
    func testsetObject() async throws {
        try await storage.setObject(testObject, forKey: key)
        let fileExist = fileManager.fileExists(atPath: storage.makeFilePath(for: key))
        XCTAssertTrue(fileExist)
    }
    
    /// Test that
    func testCacheEntry() async throws {
        // Returns nil if entry doesn't exist
        var entry: Entry<User>?
        do {
            entry = try await storage.entry(forKey: key)
        } catch {
            
        }
        XCTAssertNil(entry)
        
        // Returns entry if object exists
        try await storage.setObject(testObject, forKey: key)
        entry = try await storage.entry(forKey: key)
        let attributes = try fileManager.attributesOfItem(atPath: storage.makeFilePath(for: key))
        let expiry = Expiry.date(attributes[FileAttributeKey.modificationDate] as! Date)
        
        XCTAssertEqual(entry?.object.firstName, testObject.firstName)
        XCTAssertEqual(entry?.object.lastName, testObject.lastName)
        XCTAssertEqual(entry?.expiry.date, expiry.date)
    }
    
    func testCacheEntryPath() async throws {
        let key = "test.mp4"
        try await storage.setObject(testObject, forKey: key)
        let entry = try await storage.entry(forKey: key)
        let filePath = storage.makeFilePath(for: key)
        
        XCTAssertEqual(entry.filePath, filePath)
    }
    
    /// Test that it resolves cached object
    func testSetObject() async throws {
        try await storage.setObject(testObject, forKey: key)
        let cachedObject: User? = try await storage.object(forKey: key)
        
        XCTAssertEqual(cachedObject?.firstName, testObject.firstName)
        XCTAssertEqual(cachedObject?.lastName, testObject.lastName)
    }
    
    /// Test that it removes cached object
    func testRemoveObject() async throws {
        try await storage.setObject(testObject, forKey: key)
        try await storage.removeObject(forKey: key)
        let fileExist = fileManager.fileExists(atPath: storage.makeFilePath(for: key))
        XCTAssertFalse(fileExist)
    }
    
    /// Test that it removes expired object
    func testRemoveObjectIfExpiredWhenExpired() async throws {
        let expiry: Expiry = .date(Date().addingTimeInterval(-100000))
        try await storage.setObject(testObject, forKey: key, expiry: expiry)
        try storage.removeObjectIfExpired(forKey: key)
        var cachedObject: User?
        do {
            cachedObject = try await storage.object(forKey: key)
        } catch {}
        
        XCTAssertNil(cachedObject)
    }
    
    /// Test that it doesn't remove not expired object
    func testRemoveObjectIfExpiredWhenNotExpired() async throws {
        try await storage.setObject(testObject, forKey: key)
        try storage.removeObjectIfExpired(forKey: key)
        let cachedObject: User? = try await storage.object(forKey: key)
        XCTAssertNotNil(cachedObject)
    }
    
    /// Test expired object
    func testExpiredObject() async throws {
        try await storage.setObject(testObject, forKey: key, expiry: .seconds(2))
        let isExpired = try await storage.isExpiredObject(forKey: key)
        XCTAssertFalse(isExpired)
        
        sleep(2)
        
        let isExpiredNow = try await storage.isExpiredObject(forKey: key)
        XCTAssertTrue(isExpiredNow)
    }
    
    /// Test that it clears cache directory
    func testClear() async throws {
        try await storage.setObject(testObject, forKey: key)
        
        do {
            try await storage.removeAll()
        } catch {
            XCTFail(error.localizedDescription)
        }
        
        let fileExist = fileManager.fileExists(atPath: storage.path)
        XCTAssertTrue(fileExist)
        
        let contents = try? fileManager.contentsOfDirectory(atPath: storage.path)
        XCTAssertEqual(contents?.count, 0)
    }
    
    /// Test that it clears cache files, but keeps root directory.
    ///
    func testCreateDirectory() async {
        do {
            try await storage.removeAll()
            XCTAssertTrue(fileManager.fileExists(atPath: storage.path))
            let contents = try? fileManager.contentsOfDirectory(atPath: storage.path)
            XCTAssertEqual(contents?.count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// Test that it removes expired objects.
    ///
    func testClearExpired() async throws {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-100000))
        let expiry2: Expiry = .date(Date().addingTimeInterval(100000))
        let key1 = "item1"
        let key2 = "item2"
        try await storage.setObject(testObject, forKey: key1, expiry: expiry1)
        try await storage.setObject(testObject, forKey: key2, expiry: expiry2)
        try await storage.removeExpiredObjects()
        var object1: User?
        let object2 = try await storage.object(forKey: key2)
        
        do {
            object1 = try await storage.object(forKey: key1)
        } catch {}
        
        XCTAssertNil(object1)
        XCTAssertNotNil(object2)
    }
    
    /// Test that it returns a correct file name.
    ///
    func testMakeFileName() {
        XCTAssertEqual(storage.makeFileName(for: key), MD5(key))
        XCTAssertEqual(storage.makeFileName(for: "test.mp4"), "\(MD5("test.mp4")).mp4")
    }
    
    /// Test that it returns a correct file path.
    ///
    func testMakeFilePath() {
        let filePath = "\(storage.path)/\(storage.makeFileName(for: key))"
        XCTAssertEqual(storage.makeFilePath(for: key), filePath)
    }
    
}

