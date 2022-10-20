import XCTest
@testable import Cache

final class StorageSupportTests: XCTestCase {
    
    private var storage: HybridStorage<String, Bool>!
    
    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, Bool>(config: MemoryConfig())
        let disk = try! DiskStorage<String, Bool>(config: DiskConfig(name: "PrimitiveDisk"), transformer: TransformerFactory.forCodable(ofType: Bool.self))
        storage = HybridStorage<String, Bool>(memoryStorage: memory, diskStorage: disk)
    }
    
    override func tearDown() {
        Task {
            try? await storage.removeAll()
        }
        super.tearDown()
    }
    
    func testSetPrimitive() async throws {
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Bool.self))
            try await s.setObject(true, forKey: "bool", expiry: .never)
            let loadedBool = try await s.object(forKey: "bool")
            XCTAssertEqual(loadedBool, true)
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [Bool].self))
            try await s.setObject([true, false, true], forKey: "array of bools", expiry: .never)
            let loadedBools = try await s.object(forKey: "array of bools")
            XCTAssertEqual(loadedBools, [true, false, true])
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: String.self))
            try await s.setObject("one", forKey: "string", expiry: .never)
            let loadedString = try await s.object(forKey: "string")
            XCTAssertEqual(loadedString, "one")
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [String].self))
            try await s.setObject(["one", "two", "three"], forKey: "array of strings", expiry: .never)
            let loadedStrings = try await s.object(forKey: "array of strings")
            XCTAssertEqual(loadedStrings, ["one", "two", "three"])
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
            try await s.setObject(10, forKey: "int", expiry: .never)
            let loadedInt = try await s.object(forKey: "int")
            XCTAssertEqual(loadedInt, 10)
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [Int].self))
            try await s.setObject([1, 2, 3], forKey: "array of ints", expiry: .never)
            let loadedArrayInts = try await s.object(forKey: "array of ints")
            XCTAssertEqual(loadedArrayInts, [1, 2, 3])
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Float.self))
            let float: Float = 1.1
            try await s.setObject(float, forKey: "float", expiry: .never)
            let loadedFloat = try await s.object(forKey: "float")
            XCTAssertEqual(loadedFloat, float)
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [Float].self))
            let floats: [Float] = [1.1, 1.2, 1.3]
            try await s.setObject(floats, forKey: "array of floats", expiry: .never)
            let loadedFloats = try await s.object(forKey: "array of floats")
            XCTAssertEqual(loadedFloats, floats)
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Double.self))
            let double: Double = 1.1
            try await s.setObject(double, forKey: "double", expiry: .never)
            let loaded = try await s.object(forKey: "double")
            XCTAssertEqual(loaded, double)
        }
        
        do {
            let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [Double].self))
            let doubles: [Double] = [1.1, 1.2, 1.3]
            try await s.setObject(doubles, forKey: "array of doubles", expiry: .never)
            let loadedArray = try await s.object(forKey: "array of doubles")
            XCTAssertEqual(loadedArray, doubles)
        }
    }
    
    func testSetData() async {
        let s = storage.transform(transformer: TransformerFactory.forData())
        
        do {
            let string = "Hello"
            let data = string.data(using: .utf8)!
            try await s.setObject(data, forKey: "data", expiry: .never)
            
            let cachedObject = try await s.object(forKey: "data")
            let cachedString = String(data: cachedObject, encoding: .utf8)
            
            XCTAssertEqual(cachedString, string)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testSetDate() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Date.self))
        
        let date = Date(timeIntervalSince1970: 100)
        try await s.setObject(date, forKey: "date", expiry: .never)
        let cachedObject = try await s.object(forKey: "date")
        
        XCTAssertEqual(date, cachedObject)
    }
    
    func testSetURL() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: URL.self))
        let url = URL(string: "https://hyper.no")!
        try await s.setObject(url, forKey: "url", expiry: .never)
        let cachedObject = try await s.object(forKey: "url")
        
        XCTAssertEqual(url, cachedObject)
    }
    
    func testWithSet() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Set<Int>.self))
        let set = Set<Int>(arrayLiteral: 1, 2, 3)
        try await s.setObject(set, forKey: "set", expiry: .never)
        let loaded = try await s.object(forKey: "set") as Set<Int>
        XCTAssertEqual(loaded, set)
    }
    
    func testWithSimpleDictionary() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: [String: Int].self))
        
        let dict: [String: Int] = [
            "key1": 1,
            "key2": 2
        ]
        
        try await s.setObject(dict, forKey: "dict", expiry: .never)
        let cachedObject = try await s.object(forKey: "dict") as [String: Int]
        XCTAssertEqual(cachedObject, dict)
    }
    
    func testWithComplexDictionary() {
        let _: [String: Any] = [
            "key1": 1,
            "key2": 2
        ]
        
        // fatal error: Dictionary<String, Any> does not conform to Encodable because Any does not conform to Encodable
        // try storage.setObject(dict, forKey: "dict")
    }
    
    func testIntFloat() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Float.self))
        let key = "key"
        try await s.setObject(10, forKey: key, expiry: .never)
        let loadedObj = try await s.object(forKey: key)
        XCTAssertEqual(loadedObj, 10)
        
        let intStorage = s.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
        let loadedIntObj = try await intStorage.object(forKey: key)
        XCTAssertEqual(loadedIntObj, 10)
    }
    
    func testFloatDouble() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: Float.self))
        let key = "key"
        try await s.setObject(10.5, forKey: key, expiry: .never)
        
        let sObjectKey = try await s.object(forKey: key)
        XCTAssertEqual(sObjectKey, 10.5)
        
        let doubleStorage = s.transform(transformer: TransformerFactory.forCodable(ofType: Double.self))
        let doubleStorKeyObject = try await doubleStorage.object(forKey: key)
        XCTAssertEqual(doubleStorKeyObject, 10.5)
    }
    
    func testCastingToAnotherType() async throws {
        let s = storage.transform(transformer: TransformerFactory.forCodable(ofType: String.self))
        try await s.setObject("Hello", forKey: "string", expiry: .never)
        
        do {
            let intStorage = s.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
            let _ = try await intStorage.object(forKey: "string")
            XCTFail()
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testOverridenOnDisk() async throws {
        let intStorage = storage.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
        let stringStorage = storage.transform(transformer: TransformerFactory.forCodable(ofType: String.self))
        
        let key = "sameKey"
        
        try await intStorage.setObject(1, forKey: key, expiry: .never)
        try await stringStorage.setObject("hello world", forKey: key, expiry: .never)
        
        let intValue = try? await intStorage.diskStorage.object(forKey: key)
        let stringValue = try? await stringStorage.diskStorage.object(forKey: key)
        
        XCTAssertNil(intValue)
        XCTAssertNotNil(stringValue)
    }
    
}
