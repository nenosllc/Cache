import XCTest
import Dispatch
@testable import Cache

final class SyncStorageTests: XCTestCase {
    
    private var storage: SyncStorage<String, User>!
    let user = User(firstName: "John", lastName: "Snow")
    
    override func setUp() {
        super.setUp()
        
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(config: DiskConfig(name: "HybridDisk"), transformer: TransformerFactory.forCodable(ofType: User.self))
        
        let hybridStorage = HybridStorage(memoryStorage: memory, diskStorage: disk)
        storage = SyncStorage(storage: hybridStorage)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testSetObject() async throws {
        try await storage.setObject(user, forKey: "user", expiry: .never)
        let cachedObject = try await storage.object(forKey: "user")
        
        XCTAssertEqual(cachedObject, user)
    }
    
    func testRemoveAll() async throws {
        let intStorage = await storage.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
        try await Array(0..<100).asyncForEach({ index in
            try await intStorage.setObject(index, forKey: "key-\(index)", expiry: .never)
        })
        
        try await intStorage.removeAll()
        let exists = await intStorage.objectExists(forKey: "key-99")
        XCTAssertFalse(exists)
    }
    
}
