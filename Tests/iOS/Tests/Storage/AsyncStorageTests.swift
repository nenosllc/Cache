import XCTest
import Dispatch
@testable import Cache

final class AsyncStorageTests: XCTestCase {
    private var storage: AsyncStorage<String, User>!
    let user = User(firstName: "John", lastName: "Snow")
    
    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(config: DiskConfig(name: "Async Disk"), transformer: TransformerFactory.forCodable(ofType: User.self))
        let hybrid = HybridStorage<String, User>(memoryStorage: memory, diskStorage: disk)
        storage = AsyncStorage(storage: hybrid)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        
        super.tearDown()
    }
    
    func testSetObject() async throws {
        try? await storage.setObject(user, forKey: "user", expiry: .never)
        let result = try! await storage.object(forKey: "user")
        XCTAssertEqual(result, self.user)
    }
    
    func testRemoveAll() async {
        let intStorage = await storage.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
        
        await Array(0..<100).asyncForEach { index in
            try? await intStorage.setObject(index, forKey: "key-\(index)", expiry: .never)
        }
        
        try? await intStorage.removeAll()
        
        let exists = await intStorage.objectExists(forKey: "key-99")
        if exists == true {
            XCTFail()
        }
    }
    
}
