import Foundation

/// 예약할 알림 하나. `UNNotificationRequest`로 옮기기 전의 값 타입이다.
///
/// 스케줄러를 이 값 타입까지만 다루게 해두면 `UNUserNotificationCenter` 없이
/// "무엇을 언제 예약하는가"를 테스트할 수 있다.
struct CycleReminder: Equatable, Sendable {
    /// 예정일 며칠 전인지. 식별자와 문구를 결정한다.
    let daysBefore: Int
    /// 알림이 뜰 시각.
    let fireDate: Date
    let title: String
    let body: String

    /// PRD 7.1이 정한 식별자 규칙. 재예약할 때 이 값으로 기존 예약을 지운다.
    var identifier: String {
        "period-reminder-\(daysBefore)d"
    }

    /// 알림을 탭했을 때 이동할 화면. PRD 7.1의 `userInfo` 라우팅.
    var userInfo: [String: String] {
        [NotificationRoute.key: NotificationRoute.home.rawValue]
    }
}

/// 알림 탭 시 이동할 화면. `userInfo`에 실어 보낸다.
enum NotificationRoute: String, Sendable {
    static let key = "route"

    case home
}

/// 알림 문구.
///
/// 남이 화면을 봐도 무슨 앱인지 알아채기 어려워야 한다(UX-설계 3번, PRD 3번).
/// 그래서 "생리" 같은 단어를 쓰지 않고 "예정일"로만 표현한다.
/// 온보딩 프리퍼미션 화면에서도 이 점을 약속하고 있다.
enum CycleReminderText {
    static func title(daysBefore: Int) -> String {
        daysBefore <= 1 ? "내일이 예정일이에요" : "예정일이 다가와요"
    }

    static func body(daysBefore: Int) -> String {
        daysBefore <= 1
            ? "미리 준비해 두면 좋아요."
            : "\(daysBefore)일 뒤예요. 미리 준비해 두면 좋아요."
    }
}
