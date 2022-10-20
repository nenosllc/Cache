import Foundation

public extension CacheStorage {
    
    func transformData() -> CacheStorage<Key, Data> {
        let storage = transform(transformer: TransformerFactory.forData())
        return storage
    }
    
    #if os(iOS) || os(tvOS) || os(macOS)
    func transformImage() -> CacheStorage<Key, CacheImage> {
        let storage = transform(transformer: TransformerFactory.forImage())
        return storage
    }
    #endif
    
    func transformCodable<U: Codable>(ofType: U.Type) -> CacheStorage<Key, U> {
        let storage = transform(transformer: TransformerFactory.forCodable(ofType: U.self))
        return storage
    }
    
}
