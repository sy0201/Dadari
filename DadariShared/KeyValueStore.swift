import Foundation

/// 저장소를 프로토콜로 추상화해서 테스트에서 실제 UserDefaults 없이 검증할 수 있게 한다.
protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func setData(_ data: Data?, forKey key: String) {
        if let data {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

/// 테스트용 인메모리 구현.
final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Data]

    init(storage: [String: Data] = [:]) {
        self.storage = storage
    }

    func data(forKey key: String) -> Data? {
        storage[key]
    }

    func setData(_ data: Data?, forKey key: String) {
        storage[key] = data
    }
}
