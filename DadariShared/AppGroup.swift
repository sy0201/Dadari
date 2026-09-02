import Foundation

/// 앱과 위젯 익스텐션이 같은 컨테이너를 보게 하는 App Group 식별자.
/// 위젯이 주 입력 경로이므로, 두 프로세스가 같은 저장소를 공유하는 게 전제 조건이다.
enum AppGroup {
    static let identifier = "group.com.dadari.app"

    /// App Group 컨테이너 경로. 엔타이틀먼트가 실제로 적용됐는지 판단하는 신뢰할 수 있는 유일한 경로다.
    ///
    /// `UserDefaults(suiteName:)`는 엔타이틀먼트가 없어도 nil이 아닌 객체를 돌려주기 때문에
    /// 연결 여부의 근거가 되지 못한다. 반면 `containerURL(forSecurityApplicationGroupIdentifier:)`는
    /// 엔타이틀먼트가 없거나 프로비저닝 프로파일에 App Group이 빠져 있으면 nil을 반환한다.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var isAvailable: Bool {
        containerURL != nil
    }

    /// App Group 컨테이너의 UserDefaults. 컨테이너를 잡지 못하면 nil을 돌려줘서
    /// 호출부가 "공유되는 척하는 저장소"를 쓰지 않도록 한다.
    static var sharedDefaults: UserDefaults? {
        guard isAvailable else { return nil }
        return UserDefaults(suiteName: identifier)
    }
}
