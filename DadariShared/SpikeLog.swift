import OSLog

/// 스파이크 검증용 로그.
///
/// 위젯 익스텐션은 별개 프로세스라 앱을 실행 중이어도 Xcode 콘솔에 로그가 섞여 나오지 않는다.
/// macOS의 Console.app에서 기기를 선택하고 `subsystem: com.dadari.app`으로 필터링하면
/// 잠금화면 탭이 실제로 인텐트를 실행했는지 눈으로 확인할 수 있다.
///
/// 기본 로그는 문자열 보간을 private으로 가려버리므로, 확인해야 할 값은 `privacy: .public`으로 남긴다.
/// 스파이크 단계라 실제 기록 날짜까지 공개로 찍지만, 정식 구현에서는 건강 데이터를 로그에 남기지 않는다.
enum SpikeLog {
    static let subsystem = "com.dadari.app"

    static let intent = Logger(subsystem: subsystem, category: "intent")
    static let store = Logger(subsystem: subsystem, category: "store")
}
