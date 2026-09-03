import OSLog

/// 앱과 위젯 익스텐션이 함께 쓰는 로그.
///
/// 위젯 익스텐션은 별개 프로세스라 Xcode 콘솔에 로그가 섞여 나오지 않는다.
/// macOS의 Console.app에서 기기를 선택하고 `subsystem:com.dadari.app`으로 필터링하면
/// 잠금화면 탭이 실제로 인텐트를 실행했는지 확인할 수 있다(SPIKE.md).
///
/// 기본 로그는 문자열 보간을 private으로 가린다. 확인이 필요한 값만 `privacy: .public`으로
/// 남기고, 실제 기록 날짜 같은 건강 데이터는 공개로 찍지 않는다.
enum DadariLog {
    static let subsystem = "com.dadari.app"

    static let intent = Logger(subsystem: subsystem, category: "intent")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let health = Logger(subsystem: subsystem, category: "health")
}
