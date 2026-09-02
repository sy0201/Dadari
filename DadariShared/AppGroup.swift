import Foundation

/// 앱과 위젯 익스텐션이 같은 컨테이너를 보게 하는 App Group 식별자.
/// 위젯이 주 입력 경로이므로, 두 프로세스가 같은 저장소를 공유하는 게 전제 조건이다.
enum AppGroup {
    static let identifier = "group.com.dadari.app"

    /// App Group 컨테이너의 UserDefaults. 프로비저닝이 잘못돼 있으면 nil이 되므로
    /// 호출부에서 실패를 감지할 수 있도록 옵셔널을 그대로 노출한다.
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}
