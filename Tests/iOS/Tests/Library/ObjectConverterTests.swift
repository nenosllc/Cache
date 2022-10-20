import XCTest
@testable import Cache

final class JSONDecoderExtensionsTests: XCTestCase {
    private var storage: HybridStorage<String, User>!
    
    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(
            config: DiskConfig(name: "HybridDisk"),
            transformer: TransformerFactory.forCodable(ofType: User.self)
        )
        
        storage = HybridStorage(memoryStorage: memory, diskStorage: disk)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testJsonDictionary() async throws {
        let json: [String: Any] = [
            "first_name": "John",
            "last_name": "Snow"
        ]
        
        let user = try JSONDecoder.decode(json, to: User.self)
        try await storage.setObject(user, forKey: "user", expiry: .never)
        
        let cachedObject = try await storage.object(forKey: "user")
        XCTAssertEqual(user, cachedObject)
    }
    
    func testJsonString() async throws {
        let string: String = "{\"first_name\": \"John\", \"last_name\": \"Snow\"}"
        
        let user = try JSONDecoder.decode(string, to: User.self)
        try await storage.setObject(user, forKey: "user", expiry: .never)
        
        let cachedObject = try await storage.object(forKey: "user")
        XCTAssertEqual(cachedObject.firstName, "John")
    }
    
}

